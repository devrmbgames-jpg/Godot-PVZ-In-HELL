extends SceneTree
## Проверяет авторские ресурсы LimboAI, не перезаписывая настройки поведения.

const TREE_PATHS: PackedStringArray = [
	"res://content/domains/customers/ai/trees/bt_district_npc.tres",
	"res://content/domains/npc/ai/trees/bt_npc_native.tres",
	"res://content/domains/npc/ai/trees/bt_npc_conversation.tres",
	"res://content/domains/npc/ai/trees/bt_npc_emergency.tres",
	"res://content/domains/npc/ai/trees/bt_npc_combat.tres",
	"res://content/domains/customers/ai/trees/bt_npc_service.tres",
	"res://content/domains/npc/ai/trees/bt_npc_schedule.tres",
	"res://content/domains/npc/ai/trees/bt_npc_idle.tres",
	"res://content/domains/customers/ai/trees/bt_npc_delivery_ambush.tres",
]

var _failed: bool = false

#region Проверка ресурсов
func _init() -> void:
	_validate.call_deferred()

func _validate() -> void:
	var leaf_count: int = 0
	for tree_path: String in TREE_PATHS:
		var tree: BehaviorTree = load(tree_path) as BehaviorTree
		if tree == null or tree.get_root_task() == null:
			_fail(tree_path + ": нет корня дерева")
			continue
		var root: BTTask = tree.get_root_task()
		if tree_path == TREE_PATHS[0] and (not root is BTDynamicSelector or root.get_child_count() != 6):
			_fail("Главный reactive selector должен иметь шесть приоритетов")
		if tree_path != TREE_PATHS[0] and root.get_child_count() < 2:
			_fail(tree_path + ": скрытая одиночная ветка вместо композиции")
		leaf_count += _check_task(root)
	print("District trees: ", TREE_PATHS.size(), " resources, ", leaf_count, " leaves, ", "FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)

func _check_task(task: BTTask) -> int:
	var count: int = 0
	if task.get_child_count() == 0 and not task is BTSubtree:
		count = 1
		if not task is BTAction and not task is BTCondition:
			_fail(task.custom_name + ": неизвестный лист")
		var task_script: Script = task.get_script() as Script
		if task_script != null and task_script.get_source_code().contains("execute_branch"):
			_fail(task.custom_name + ": обнаружен старый диспетчер")
	for child_index: int in task.get_child_count():
		count += _check_task(task.get_child(child_index))
	return count

func _fail(reason: String) -> void:
	_failed = true
	push_error(reason)
#endregion
