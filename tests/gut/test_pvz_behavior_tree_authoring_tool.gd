extends GutTest
## Native resource identity and refusal gates for bounded editor-only tree authoring.

const AuthoringTool = preload("res://addons/pvz_ai_tools/behavior_tree_authoring_tool.gd")


#region Nested native insertion
func _nested_params() -> Dictionary:
	var path: String = AuthoringTool.CUSTOMER_TREE_DIRECTORY + "bt_npc_service.tres"
	return {
		"op": "insert_nested",
		"path": path,
		"fingerprint": FileAccess.get_sha256(path),
		"task_path": [1, 1, 3, 1],
		"subtree": AuthoringTool.TREE_DIRECTORY + "bt_npc_stalking.tres",
		"index": 0,
		"expected_children": [
			"Место выдачи достигнуто", "Не удалось добраться", "Идти к стойке или двери",
		],
		"name": "Prepared rear service",
	}


func _arrival_selector(tree: BehaviorTree) -> BTTask:
	return tree.get_root_task().get_child(1).get_child(1).get_child(3).get_child(1)


func test_nested_insert_preserves_cached_tree_siblings_and_native_properties() -> void:
	var params: Dictionary = _nested_params()
	var cached: BehaviorTree = load(params.path) as BehaviorTree
	var original: BTTask = _arrival_selector(cached)
	var prepared: Dictionary = AuthoringTool.prepare_nested_insert(params)
	assert_false(prepared.has("error"))
	if prepared.has("error"):
		return
	var tree: BehaviorTree = prepared.tree
	var selector: BTTask = _arrival_selector(tree)
	assert_not_same(tree, cached)
	assert_not_same(selector, original)
	assert_eq(selector.get_child_count(), 4)
	assert_eq(selector.get_child(0).get_custom_name(), "Prepared rear service")
	assert_same(
		(selector.get_child(0) as BTSubtree).subtree, load(params.subtree) as BehaviorTree,
	)
	assert_eq(AuthoringTool.child_names(original), params.expected_children)
	assert_eq(selector.get_child(1).get_custom_name(), original.get_child(0).get_custom_name())
	var retained_timeout: BTTask = selector.get_child(2).get_child(0)
	assert_eq(retained_timeout.get("seconds_property"), &"approach_timeout")
	assert_eq(
		tree.get_root_task().get_child(0).get_custom_name(),
		cached.get_root_task().get_child(0).get_custom_name(),
	)
	assert_eq(tree.description, cached.description)
	assert_eq(FileAccess.get_sha256(params.path), params.fingerprint)
	assert_true(AuthoringTool.prepare_nested_insert(params, cached).has("error"))
	assert_true(AuthoringTool.prepare_nested_insert(params, original).has("error"))


func test_nested_insert_refuses_stale_guards_invalid_paths_and_recursion() -> void:
	var params: Dictionary = _nested_params()
	var fingerprint: String = params.fingerprint
	params.fingerprint = "stale"
	assert_true(AuthoringTool.prepare_nested_insert(params).has("error"))
	params.fingerprint = fingerprint
	params.expected_children = ["Stale order"]
	assert_true(AuthoringTool.prepare_nested_insert(params).has("error"))
	params = _nested_params()
	params.subtree = params.path
	assert_true(AuthoringTool.prepare_nested_insert(params).has("error"))
	params = _nested_params()
	for invalid: Array in [[], [99], [-1], [0.5], [INF], ["1"], [0]]:
		params.task_path = invalid
		assert_true(AuthoringTool.prepare_nested_insert(params).has("error"), str(invalid))
	params.task_path = [1, 1, 3, 1]
	for invalid: Variant in [-1, 65, INF, NAN, 0.5, "0", null]:
		params.index = invalid
		assert_true(AuthoringTool.prepare_nested_insert(params).has("error"), str(invalid))
	params.index = 0
	params.unexpected = true
	assert_true(AuthoringTool.prepare_nested_insert(params).has("error"))
	assert_eq(FileAccess.get_sha256(params.path), fingerprint)


func test_nested_insert_rejects_a_reference_to_another_incarnation_of_containing_tree() -> void:
	var params: Dictionary = _nested_params()
	var cached: BehaviorTree = load(params.path) as BehaviorTree
	var isolated: BehaviorTree = ResourceLoader.load(
		params.path, "BehaviorTree", ResourceLoader.CACHE_MODE_IGNORE,
	) as BehaviorTree
	assert_not_same(cached, isolated)
	assert_null(AuthoringTool.insert_branch(
		isolated, cached, 0, AuthoringTool.child_names(isolated.get_root_task()), "Recursive",
	))
	assert_null(AuthoringTool.insert_branch(
		cached, isolated, 0, AuthoringTool.child_names(cached.get_root_task()), "Recursive",
	))


func test_customer_leaf_graph_uses_only_direct_owned_task_paths() -> void:
	var graph: Dictionary = {
		"type": "BTAction",
		"script": AuthoringTool.CUSTOMER_TASK_DIRECTORY + "bt_npc_approach_service.gd",
		"intent_owner": C_NpcDecision.Owner.SERVICE,
	}
	var task: BTTask = AuthoringTool.build_task(graph)
	assert_not_null(task)
	if task != null:
		assert_eq(task.get("intent_owner"), C_NpcDecision.Owner.SERVICE)
	for invalid: String in [
		AuthoringTool.CUSTOMER_TASK_DIRECTORY + "../tasks/bt_npc_approach_service.gd",
		AuthoringTool.CUSTOMER_TASK_DIRECTORY + "nested/task.gd",
		"res://content/scenes/main_level.gd",
	]:
		graph.script = invalid
		assert_null(AuthoringTool.build_task(graph))
#endregion


func test_replacement_prepares_detached_root_without_writing_or_mutating_cached_tree() -> void:
	var path: String = AuthoringTool.TREE_DIRECTORY + "bt_npc_ranged_combat.tres"
	var cached: BehaviorTree = load(path) as BehaviorTree
	var original: BTTask = cached.get_root_task()
	var fingerprint: String = FileAccess.get_sha256(path)
	var params: Dictionary = {
		"op": "replace",
		"path": path,
		"fingerprint": fingerprint,
		"root": { "type": "BTSequence", "name": "Prepared" },
	}
	var prepared: Dictionary = AuthoringTool.prepare_replacement(params)
	assert_false(prepared.has("error"))
	var tree: BehaviorTree = prepared.tree
	assert_not_same(tree, cached)
	assert_eq(tree.get_root_task().get_custom_name(), "Prepared")
	assert_same(cached.get_root_task(), original)
	assert_eq(FileAccess.get_sha256(path), fingerprint)
	assert_true(AuthoringTool.prepare_replacement(params, cached).has("error"))
	params.fingerprint = "stale"
	assert_true(AuthoringTool.prepare_replacement(params).has("error"))
	params.fingerprint = fingerprint
	params.root = { "type": "Node" }
	assert_true(AuthoringTool.prepare_replacement(params).has("error"))
	assert_same(cached.get_root_task(), original)
	assert_eq(FileAccess.get_sha256(path), fingerprint)


func test_insert_retains_existing_native_resources_and_rejects_stale_order() -> void:
	var tree: BehaviorTree = BehaviorTree.new()
	var root_task: BTDynamicSelector = BTDynamicSelector.new()
	var existing: BTSequence = BTSequence.new()
	existing.set_custom_name("Existing")
	root_task.add_child(existing)
	tree.set_root_task(root_task)
	var subtree: BehaviorTree = BehaviorTree.new()
	subtree.set_root_task(BTSequence.new())
	assert_null(AuthoringTool.insert_branch(tree, subtree, 0, ["Stale"], "New"))
	assert_eq(root_task.get_child_count(), 1)
	var added: BTSubtree = AuthoringTool.insert_branch(tree, subtree, 1, ["Existing"], "New")
	assert_not_null(added)
	assert_same(tree.get_root_task(), root_task)
	assert_same(root_task.get_child(0), existing)
	assert_same(root_task.get_child(1), added)
	assert_same(added.subtree, subtree)
	assert_null(AuthoringTool.insert_branch(tree, subtree, 1, ["Existing", "New"], "Duplicate"))
	assert_eq(root_task.get_child_count(), 2)


func test_recursive_subtree_is_refused_before_mutation() -> void:
	var tree: BehaviorTree = BehaviorTree.new()
	tree.set_root_task(BTDynamicSelector.new())
	var subtree: BehaviorTree = BehaviorTree.new()
	var cycle: BTSubtree = BTSubtree.new()
	cycle.subtree = tree
	subtree.set_root_task(cycle)
	assert_null(AuthoringTool.insert_branch(tree, subtree, 0, [], "Cycle"))
	assert_eq(tree.get_root_task().get_child_count(), 0)
	cycle.subtree = null


func test_native_graph_refuses_unknown_properties_foreign_scripts_and_budget_overflow() -> void:
	var task: BTTask = AuthoringTool.build_task(
		{ "type": "BTSequence", "children": [{ "type": "BTAction", "name": "Leaf" }] }
	)
	assert_not_null(task)
	assert_eq(task.get_child(0).get_custom_name(), "Leaf")
	assert_null(AuthoringTool.build_task({ "type": "Node" }))
	assert_null(AuthoringTool.build_task({ "type": "BTSequence", "arbitrary": 1 }))
	assert_null(
		AuthoringTool.build_task(
			{ "type": "BTAction", "script": "res://addons/pvz_ai_tools/plugin.gd" }
		)
	)
	var children: Array = []
	for _index: int in 65:
		children.append({ "type": "BTAction" })
	assert_null(AuthoringTool.build_task({ "type": "BTSequence", "children": children }))
	assert_not_null(
		AuthoringTool.build_task({ "type": "BTSequence" }),
		"Each operation receives its own budget",
	)
	assert_null(
		AuthoringTool.build_task({ "type": "BTAction", "children": [{ "type": "BTAction" }] })
	)


func test_native_cooldown_requires_bounded_duration_one_child_and_typed_properties() -> void:
	var graph: Dictionary = {
		"type": "BTCooldown",
		"duration": 3.0,
		"trigger_on_failure": true,
		"children": [{ "type": "BTAction" }],
	}
	var cooldown: BTCooldown = AuthoringTool.build_task(graph) as BTCooldown
	assert_not_null(cooldown)
	assert_eq(cooldown.duration, 3.0)
	assert_true(cooldown.trigger_on_failure)
	assert_eq(cooldown.get_child_count(), 1)
	for duration: Variant in [null, "3", -1.0, 0.0, 0.09, 61.0, NAN, INF]:
		graph.duration = duration
		assert_null(AuthoringTool.build_task(graph))
	graph.duration = 3.0
	graph.trigger_on_failure = 1
	assert_null(AuthoringTool.build_task(graph))
	graph.trigger_on_failure = true
	graph.children = []
	assert_null(AuthoringTool.build_task(graph))
	graph.children = [{ "type": "BTAction" }, { "type": "BTAction" }]
	assert_null(AuthoringTool.build_task(graph))
	assert_null(AuthoringTool.build_task({ "type": "BTSequence", "duration": 3.0 }))
	assert_null(AuthoringTool.build_task({ "type": "BTAction", "trigger_on_failure": true }))


func test_only_direct_npc_tree_files_are_authorable() -> void:
	assert_true(
		AuthoringTool.valid_tree_path(
			AuthoringTool.CUSTOMER_TREE_DIRECTORY + "bt_district_npc.tres"
		)
	)
	assert_true(AuthoringTool.valid_tree_path(AuthoringTool.TREE_DIRECTORY + "bt_npc_blood.tres"))
	assert_false(AuthoringTool.valid_tree_path(AuthoringTool.TREE_DIRECTORY + "../other.tres"))
	assert_false(AuthoringTool.valid_tree_path(AuthoringTool.TREE_DIRECTORY + "nested/tree.tres"))
	assert_false(AuthoringTool.valid_tree_path("res://content/ui/main_menu.tscn"))


func test_shared_acyclic_graph_obeys_one_whole_operation_budget() -> void:
	var target: BehaviorTree = BehaviorTree.new()
	target.set_root_task(BTDynamicSelector.new())
	var candidate: BehaviorTree = BehaviorTree.new()
	candidate.set_root_task(BTSequence.new())
	for _level: int in 24:
		var parent_tree: BehaviorTree = BehaviorTree.new()
		var root_task: BTSequence = BTSequence.new()
		for _branch: int in 2:
			var subtree: BTSubtree = BTSubtree.new()
			subtree.subtree = candidate
			root_task.add_child(subtree)
		parent_tree.set_root_task(root_task)
		candidate = parent_tree
	var budget: Array[int] = [128]
	assert_true(AuthoringTool._references_tree(candidate, target, [], budget))
	assert_eq(budget[0], -1, "All nested and repeated visits consume the same bounded work")
	assert_null(AuthoringTool.insert_branch(target, candidate, 0, [], "Over budget"))
	assert_eq(target.get_root_task().get_child_count(), 0)
