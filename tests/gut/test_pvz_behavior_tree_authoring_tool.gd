extends GutTest
## Native resource identity and refusal gates for bounded editor-only tree authoring.

const AuthoringTool = preload("res://addons/pvz_ai_tools/behavior_tree_authoring_tool.gd")


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
