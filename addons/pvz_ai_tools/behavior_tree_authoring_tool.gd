@tool
extends RefCounted
## Bounded native LimboAI authoring; disk saves are explicit and non-undoable.

const TREE_DIRECTORY: String = "res://content/domains/npc/ai/trees/"
const TASK_DIRECTORY: String = "res://content/domains/npc/ai/tasks/"
const TASK_TYPES: Array[String] = [
	"BTDynamicSelector",
	"BTDynamicSequence",
	"BTSelector",
	"BTSequence",
	"BTAction",
	"BTCondition",
]


## No retained Resources, requests or connections across a registry reload.
func quiesce_for_script_swap() -> Dictionary:
	return { "ok": true }


## Create a new tree, inspect root children, or insert one subtree with an optimistic guard.
func author(params: Dictionary, _context: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return { "error": "Behavior-tree authoring requires the native editor." }
	var operation: String = String(params.get("op", ""))
	var tree_path: String = String(params.get("path", ""))
	if not valid_tree_path(tree_path):
		return { "error": "Expected a direct NPC tree .tres path." }
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


## Only direct files in the existing authored NPC tree directory are writable.
static func valid_tree_path(tree_path: String) -> bool:
	return (
		tree_path.begins_with(TREE_DIRECTORY) and tree_path.ends_with(".tres")
		and tree_path.get_base_dir() + "/" == TREE_DIRECTORY
		and not tree_path.contains("..") and not tree_path.contains("\\")
	)


## Construct at most 64 native tasks and six nested levels, before any disk mutation.
static func build_task(graph: Dictionary, depth: int = 0, budget: Array[int] = [64]) -> BTTask:
	if depth > 6 or budget[0] <= 0:
		return null
	budget[0] -= 1
	for key: Variant in graph:
		if key not in ["type", "name", "script", "intent_owner", "children"]:
			return null
	var task_type: String = String(graph.get("type", ""))
	if task_type not in TASK_TYPES:
		return null
	var task: BTTask = ClassDB.instantiate(task_type) as BTTask
	var script_path: String = String(graph.get("script", ""))
	if not script_path.is_empty():
		if (
			task_type not in ["BTAction", "BTCondition"]
			or not script_path.begins_with(TASK_DIRECTORY)
			or script_path.get_base_dir() + "/" != TASK_DIRECTORY
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
static func insert_branch(
	tree: BehaviorTree,
	subtree: BehaviorTree,
	index: int,
	expected: Array,
	branch_name: String,
) -> BTSubtree:
	if (
		tree == null or subtree == null or subtree.get_root_task() == null
		or tree.get_root_task() == null or branch_name.is_empty()
	):
		return null
	var root_task: BTTask = tree.get_root_task()
	if (
		root_task.get_class() not in ["BTDynamicSelector", "BTSelector"] or index < 0
		or index > root_task.get_child_count() or child_names(root_task) != expected
	):
		return null
	if _references_tree(subtree, tree, []):
		return null
	for child_index: int in root_task.get_child_count():
		var existing: BTSubtree = root_task.get_child(child_index) as BTSubtree
		if existing != null and existing.subtree == subtree:
			return null
	var added: BTSubtree = BTSubtree.new()
	added.subtree = subtree
	added.set_custom_name(branch_name)
	root_task.add_child_at_index(added, index)
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
