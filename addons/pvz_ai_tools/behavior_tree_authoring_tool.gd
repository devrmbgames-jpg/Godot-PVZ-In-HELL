@tool
extends RefCounted
## Bounded native LimboAI authoring; disk saves are explicit and non-undoable.

const TREE_DIRECTORY: String = "res://content/domains/npc/ai/trees/"
const CUSTOMER_TREE_DIRECTORY: String = "res://content/domains/customers/ai/trees/"
const TASK_DIRECTORY: String = "res://content/domains/npc/ai/tasks/"
const CUSTOMER_TASK_DIRECTORY: String = "res://content/domains/customers/ai/tasks/"
const TASK_TYPES: Array[String] = [
	"BTDynamicSelector",
	"BTDynamicSequence",
	"BTSelector",
	"BTSequence",
	"BTAction",
	"BTCondition",
	"BTCooldown",
]


## No retained Resources, requests or connections across a registry reload.
func quiesce_for_script_swap() -> Dictionary:
	return { "ok": true }


## Native graph creation, fingerprinted root replacement and guarded root/nested subtree insertion.
## Insert edits the loaded tree and removes its added branch on save failure; replacement uses
## an isolated graph. Success means a native file save, not a running BT instance update.
func author(params: Dictionary, _context: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return { "error": "Behavior-tree authoring requires the native editor." }
	var operation: String = String(params.get("op", ""))
	var tree_path: String = String(params.get("path", ""))
	if not valid_tree_path(tree_path):
		return { "error": "Expected a direct NPC or customer tree .tres path." }
	if operation in ["replace", "insert_nested"]:
		var expected_size: int = 4 if operation == "replace" else 8
		if params.size() != expected_size or not EditorInterface.get_unsaved_scenes().is_empty():
			return { "error": "Expected a fingerprinted replacement with clean editor scenes." }
		var inspected: Resource = EditorInterface.get_inspector().get_edited_object() as Resource
		var prepared: Dictionary = (
			prepare_replacement(params, inspected)
			if operation == "replace" else prepare_nested_insert(params, inspected)
		)
		if prepared.has("error"):
			return prepared
		var replacement: BehaviorTree = prepared.tree
		var stable_uid: int = ResourceLoader.get_resource_uid(tree_path)
		var result: Dictionary = _save(replacement, tree_path)
		if result.has("error"):
			return result
		var uid_error: Error = ResourceSaver.set_uid(tree_path, stable_uid)
		if uid_error != OK:
			return { "error": "Tree saved, UID restoration failed.", "code": uid_error }
		ResourceLoader.load(tree_path, "BehaviorTree", ResourceLoader.CACHE_MODE_REPLACE)
		return result
	if operation == "create":
		if FileAccess.file_exists(tree_path) or params.size() != 3:
			return { "error": "Create refuses existing resources and unexpected parameters." }
		var graph: Variant = params.get("root")
		if not graph is Dictionary:
			return { "error": "Expected a bounded root task description." }
		var task: BTTask = build_task(graph)
		if task == null:
			return { "error": "Invalid task graph; nothing saved." }
		var created: BehaviorTree = BehaviorTree.new()
		created.set_root_task(task)
		return _save(created, tree_path)
	var tree: BehaviorTree = load(tree_path) as BehaviorTree
	if tree == null or tree.get_root_task() == null:
		return { "error": "Existing native tree with a root is required." }
	if operation == "inspect" and params.size() == 2:
		return { "data": { "path": tree_path, "children": child_names(tree.get_root_task()) } }
	if operation != "insert" or params.size() != 6:
		return { "error": "Expected inspect, create or guarded insert parameters." }
	var subtree_path: String = String(params.get("subtree", ""))
	var expected: Variant = params.get("expected_children")
	var index_value: Variant = params.get("index")
	if (
		not valid_tree_path(subtree_path) or not expected is Array
		or not index_value is float and not index_value is int
	):
		return { "error": "Invalid subtree, index or child guard." }
	if float(index_value) != floorf(float(index_value)):
		return { "error": "Insertion index must be an integer." }
	var subtree: BehaviorTree = load(subtree_path) as BehaviorTree
	var added: BTSubtree = insert_branch(
		tree,
		subtree,
		int(index_value),
		expected,
		String(params.get("name", "")),
	)
	if added == null:
		return { "error": "Stale child guard, recursive subtree or invalid insertion; unchanged." }
	var result: Dictionary = _save(tree, tree_path)
	if result.has("error"):
		tree.get_root_task().remove_child(added)
	return result


## Prepares an isolated graph, refusing stale fingerprints or inspected target resources.
## No files or cached trees are changed before every check and native task build succeeds.
static func prepare_replacement(params: Dictionary, inspected: Resource = null) -> Dictionary:
	var path: String = String(params.get("path", ""))
	var fingerprint: String = String(params.get("fingerprint", ""))
	var graph: Variant = params.get("root")
	if (
		not valid_tree_path(path) or not FileAccess.file_exists(path)
		or fingerprint.is_empty() or FileAccess.get_sha256(path) != fingerprint
		or not graph is Dictionary or ResourceLoader.get_resource_uid(path) < 0
	):
		return { "error": "Missing native tree, stable UID, graph or exact fingerprint." }
	if (
		inspected != null
		and (inspected.resource_path == path or inspected.resource_path.begins_with(path + "::"))
	):
		return { "error": "Finish inspecting/editing the target resource before replacement." }
	var task: BTTask = build_task(graph)
	if task == null:
		return { "error": "Invalid bounded task graph; unchanged." }
	var tree: BehaviorTree = ResourceLoader.load(
		path,
		"BehaviorTree",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as BehaviorTree
	if tree == null:
		return { "error": "Expected a native BehaviorTree." }
	tree.set_root_task(task)
	return { "tree": tree }


## Prepares one nested selector insertion in an isolated native graph; siblings remain authored.
## Fingerprint, exact child names and a bounded direct-child path must all agree before mutation.
static func prepare_nested_insert(params: Dictionary, inspected: Resource = null) -> Dictionary:
	var path: String = String(params.get("path", ""))
	var fingerprint: String = String(params.get("fingerprint", ""))
	var task_path: Variant = params.get("task_path")
	var subtree_path: String = String(params.get("subtree", ""))
	var index_value: Variant = params.get("index")
	var expected: Variant = params.get("expected_children")
	for key: Variant in params:
		if key not in [
			"op", "path", "fingerprint", "task_path", "subtree", "index",
			"expected_children", "name",
		]:
			return { "error": "Unexpected nested insertion parameter." }
	if (
		params.size() != 8 or params.get("op") != "insert_nested"
		or not valid_tree_path(path) or not FileAccess.file_exists(path)
		or fingerprint.is_empty() or FileAccess.get_sha256(path) != fingerprint
		or ResourceLoader.get_resource_uid(path) < 0 or not valid_tree_path(subtree_path)
		or not FileAccess.file_exists(subtree_path)
		or not task_path is Array or task_path.is_empty() or task_path.size() > 12
		or not expected is Array or expected.size() > 64
		or (not index_value is int and not index_value is float)
	):
		return { "error": "Expected native trees, an exact fingerprint, bounded path and guard." }
	if (
		not is_finite(float(index_value)) or float(index_value) != floorf(float(index_value))
		or float(index_value) < 0.0 or float(index_value) > 64.0
	):
		return { "error": "Insertion index must be a finite integer." }
	if inspected != null and (
		inspected.resource_path == path or inspected.resource_path.begins_with(path + "::")
	):
		return { "error": "Finish inspecting/editing the target resource before insertion." }
	var tree: BehaviorTree = ResourceLoader.load(
		path, "BehaviorTree", ResourceLoader.CACHE_MODE_IGNORE,
	) as BehaviorTree
	if tree == null or tree.get_root_task() == null:
		return { "error": "Expected a native tree root." }
	var parent: BTTask = tree.get_root_task()
	for value: Variant in task_path:
		if (
			(not value is int and not value is float) or not is_finite(float(value))
			or float(value) != floorf(float(value)) or float(value) < 0.0
			or float(value) > 63.0
			or float(value) >= parent.get_child_count()
		):
			return { "error": "Nested path does not identify a direct child." }
		parent = parent.get_child(int(value))
	var subtree: BehaviorTree = load(subtree_path) as BehaviorTree
	var added: BTSubtree = _insert_at_selector(
		tree, parent, subtree, int(index_value), expected, String(params.get("name", "")),
	)
	if added == null:
		return { "error": "Stale child guard, invalid selector or recursive subtree; unchanged." }
	return { "tree": tree }


## Only direct .tres files in the authored NPC/customer tree directories are writable.
static func valid_tree_path(tree_path: String) -> bool:
	return (
		tree_path.ends_with(".tres")
		and tree_path.get_base_dir() + "/" in [TREE_DIRECTORY, CUSTOMER_TREE_DIRECTORY]
		and not tree_path.contains("..") and not tree_path.contains("\\")
	)


## Construct at most 64 native tasks and six nested levels, before any disk mutation.
## A supplied nonempty budget shares remaining count in [0]; rejected builds also consume it.
static func build_task(graph: Dictionary, depth: int = 0, budget: Array[int] = [64]) -> BTTask:
	if depth > 6 or budget[0] <= 0:
		return null
	budget[0] -= 1
	for key: Variant in graph:
		if key not in [
			"type",
			"name",
			"script",
			"intent_owner",
			"children",
			"duration",
			"trigger_on_failure",
		]:
			return null
	var task_type: String = String(graph.get("type", ""))
	if task_type not in TASK_TYPES:
		return null
	if task_type != "BTCooldown" and (graph.has("duration") or graph.has("trigger_on_failure")):
		return null
	var task: BTTask = ClassDB.instantiate(task_type) as BTTask
	if task_type == "BTCooldown":
		var seconds: Variant = graph.get("duration", null)
		var trigger: Variant = graph.get("trigger_on_failure", false)
		if (
			(not seconds is int and not seconds is float) or not trigger is bool
			or not is_finite(float(seconds)) or float(seconds) < 0.1 or float(seconds) > 60.0
		):
			return null
		var cooldown: BTCooldown = task as BTCooldown
		cooldown.duration = float(seconds)
		cooldown.trigger_on_failure = trigger
	var script_path: String = String(graph.get("script", ""))
	if not script_path.is_empty():
		if (
			task_type not in ["BTAction", "BTCondition"]
			or script_path.get_base_dir() + "/" not in [TASK_DIRECTORY, CUSTOMER_TASK_DIRECTORY]
			or script_path.get_extension() != "gd" or script_path.contains("..")
		):
			return null
		var leaf_script: GDScript = load(script_path) as GDScript
		if (
			leaf_script == null or not leaf_script.can_instantiate()
			or leaf_script.get_instance_base_type() != task_type
		):
			return null
		task.set_script(leaf_script)
	if graph.has("intent_owner"):
		if not task_type == "BTAction" or script_path.is_empty() or "intent_owner" not in task:
			return null
		var owner_value: Variant = graph["intent_owner"]
		if not owner_value is int and not owner_value is float:
			return null
		if (
			float(owner_value) != floorf(float(owner_value)) or int(owner_value) < 0
			or int(owner_value) > C_NpcDecision.Owner.NONE
		):
			return null
		task.set("intent_owner", int(owner_value))
	var children: Variant = graph.get("children", [])
	if (
		not children is Array
		or (task_type in ["BTAction", "BTCondition"] and not children.is_empty())
		or (task_type == "BTCooldown" and children.size() != 1)
	):
		return null
	for child_graph: Variant in children:
		if not child_graph is Dictionary:
			return null
		var child_task: BTTask = build_task(child_graph, depth + 1, budget)
		if child_task == null:
			return null
		task.add_child(child_task)
	task.set_custom_name(String(graph.get("name", "")))
	return task


## Preserve the actual existing root/children/Blackboard plans, refusing stale or cyclic edits.
## Success mutates the caller's tree and returns its inserted child; null leaves it unchanged.
static func insert_branch(
	tree: BehaviorTree,
	subtree: BehaviorTree,
	index: int,
	expected: Array,
	branch_name: String,
) -> BTSubtree:
	if tree == null:
		return null
	return _insert_at_selector(tree, tree.get_root_task(), subtree, index, expected, branch_name)


static func _insert_at_selector(
	tree: BehaviorTree,
	parent: BTTask,
	subtree: BehaviorTree,
	index: int,
	expected: Array,
	branch_name: String,
) -> BTSubtree:
	if (
		tree == null or subtree == null or subtree.get_root_task() == null
		or parent == null or branch_name.is_empty()
	):
		return null
	if (
		parent.get_class() not in ["BTDynamicSelector", "BTSelector"] or index < 0
		or index > parent.get_child_count() or child_names(parent) != expected
	):
		return null
	if _references_tree(subtree, tree, []):
		return null
	for child_index: int in parent.get_child_count():
		var existing: BTSubtree = parent.get_child(child_index) as BTSubtree
		if existing != null and existing.subtree == subtree:
			return null
	var added: BTSubtree = BTSubtree.new()
	added.subtree = subtree
	added.set_custom_name(branch_name)
	parent.add_child_at_index(added, index)
	return added


static func child_names(task: BTTask) -> Array[String]:
	var names: Array[String] = []
	for child_index: int in task.get_child_count():
		names.append(task.get_child(child_index).get_custom_name())
	return names


static func _references_tree(
	candidate: BehaviorTree,
	target: BehaviorTree,
	visited: Array[BehaviorTree],
	budget: Array[int] = [128],
) -> bool:
	if (
		candidate == target or candidate.get_root_task() == null
		or (
			not candidate.resource_path.is_empty()
			and candidate.resource_path == target.resource_path
		)
		or visited.has(candidate) or visited.size() >= 64
	):
		return true
	visited.append(candidate)
	var pending: Array[BTTask] = [candidate.get_root_task()]
	while not pending.is_empty():
		budget[0] -= 1
		if budget[0] < 0:
			return true
		var task: BTTask = pending.pop_back()
		var nested: BTSubtree = task as BTSubtree
		if (
			nested != null and nested.subtree != null
			and _references_tree(nested.subtree, target, visited, budget)
		):
			return true
		for child_index: int in task.get_child_count():
			pending.append(task.get_child(child_index))
	visited.erase(candidate)
	return false


func _save(tree: BehaviorTree, tree_path: String) -> Dictionary:
	var save_error: Error = ResourceSaver.save(tree, tree_path)
	if save_error != OK:
		return { "error": "Native ResourceSaver failed.", "code": save_error }
	EditorInterface.get_resource_filesystem().update_file(tree_path)
	return {
		"data": {
			"path": tree_path,
			"saved": true,
			"children": child_names(tree.get_root_task()),
			"undoable": false,
		}
	}
