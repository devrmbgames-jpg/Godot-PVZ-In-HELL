@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Requests a hidden native route behind the perceived player; never writes physical transforms.


#region Native hidden approach
func _exit() -> void:
	if is_instance_valid(_actor):
		var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
		if state.approach_task_id == get_instance_id():
			state.approach_task_id = 0
	super._exit()


func _tick(_delta: float) -> Status:
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	if not NpcStalkingQueries.eligible(_actor, _person, player):
		return FAILURE
	var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
	if NpcStalkingSolver.observed(_actor, player, _actor.global_position, state.rule):
		return FAILURE
	var destination: Vector3 = NpcStalkingSolver.destination(_actor, _person, player, state.rule)
	if not destination.is_finite() or not _claim("Жуткий: подкрасться со спины"):
		return FAILURE
	if _actor.global_position.distance_to(destination) <= state.rule.arrival_tolerance:
		_own_movement()
		NpcIntentArbiter.stop(_actor, intent_owner)
	else:
		_move(destination, state.rule.arrival_tolerance)
	state.approach_task_id = get_instance_id()
	return RUNNING
#endregion
