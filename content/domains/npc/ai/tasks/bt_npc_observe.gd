@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Наблюдает занятие и видимого игрока, окликая не чаще одного раза за фазу.


#region Листовое действие
func _exit() -> void:
	if _owns_movement and is_instance_valid(_actor):
		var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
		if decision != null and decision.active_task_id == get_instance_id():
			NpcIntentService.look_along_movement(_actor)
	super._exit()


func _tick(_delta: float) -> Status:
	if not _claim("Наблюдение"):
		return FAILURE
	if _person.rule_for(DEF_NpcTrait.Kind.GAZE_AVERSION) is DEF_NpcGazeAversion:
		_own_movement()
		NpcIntentService.look_along_movement(_actor)
	NpcIntentArbiter.stop(_actor, intent_owner)
	NpcDecisionService.observe(_actor, _person, _awareness)
	return RUNNING

#endregion
