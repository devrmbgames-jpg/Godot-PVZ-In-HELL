@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Waits for the captured GameClock start without advancing a second timer.

var _sequence: int = 0


#region Captured delay lifecycle
func _enter() -> void:
	super._enter()
	_sequence = 0


func _exit() -> void:
	if is_instance_valid(_actor):
		var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
		var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
		if (
			_owns_movement and state != null and _sequence > 0
			and state.episode_sequence == _sequence
		):
			if (
				GameTimeQueries.current().elapsed_ticks < state.ready_tick
				or decision.active_task_id != get_instance_id()
				or decision.intent_owner != intent_owner
				or not NpcStalkingQueries.eligible(
					_actor,
					_person,
					NpcStalkingQueries.target_for(_actor),
				)
			):
				NpcStalkingService.cancel(_actor)
	super._exit()


func _tick(_delta: float) -> Status:
	var player: Entity = NpcStalkingQueries.target_for(_actor)
	if not NpcStalkingQueries.eligible(_actor, _person, player):
		return FAILURE
	var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
	_sequence = state.episode_sequence
	if not _claim("Жуткий: выбранный момент"):
		return FAILURE
	if GameTimeQueries.current().elapsed_ticks >= state.ready_tick:
		return SUCCESS
	_own_movement()
	state.approach_task_id = get_instance_id()
	NpcIntentArbiter.stop(_actor, intent_owner)
	return RUNNING
#endregion
