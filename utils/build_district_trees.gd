extends SceneTree
## Regenerates editable native LimboAI subtrees from the shared branch adapter.

const OUTPUT_DIRECTORY: String = "res://content/ai/trees"
const BRANCHES: PackedStringArray = ["emergency", "combat", "service", "schedule", "idle"]

#region Resource authoring
func _init() -> void:
	_build.call_deferred()

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	var selector: BTDynamicSelector = BTDynamicSelector.new()
	var branch_script: Script = load("res://content/ai/tasks/bt_npc_branch.gd") as Script
	for branch_index: int in BRANCHES.size():
		var branch_tree: BehaviorTree = BehaviorTree.new()
		var action: BTAction = branch_script.new() as BTAction
		action.set("owner_kind", branch_index)
		action.custom_name = BRANCHES[branch_index]
		branch_tree.set_root_task(action)
		var branch_path: String = "%s/bt_npc_%s.tres" % [OUTPUT_DIRECTORY, BRANCHES[branch_index]]
		assert(ResourceSaver.save(branch_tree, branch_path) == OK)
		var subtree: BTSubtree = BTSubtree.new()
		subtree.subtree = load(branch_path) as BehaviorTree
		subtree.custom_name = BRANCHES[branch_index]
		selector.add_child(subtree)
	var tree: BehaviorTree = BehaviorTree.new()
	tree.description = "District NPC: emergency, combat/search, parcel service, phase schedule, free activity."
	tree.set_root_task(selector)
	assert(ResourceSaver.save(tree, OUTPUT_DIRECTORY + "/bt_district_npc.tres") == OK)
	print("District LimboAI resources: 5 subtrees + priority tree created")
	quit()
#endregion
