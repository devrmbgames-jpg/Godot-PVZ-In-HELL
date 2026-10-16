@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Executes a fixed hidden destination with bounded meaningful replans; the body owns movement.

var _sequence: int = 0


#region Native hidden approach lifecycle
func _enter() -> void:
	super._enter()
	_sequence = 0


func _exit() -> void:
	if is_instance_valid(_actor):
		var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
		if state != null and _sequence > 0 and state.episode_sequence == _sequence:
			NpcStalkingService.cancel(_actor)
	super._exit()


func _tick(_delta: float) -> Status:
	var player: Entity = NpcStalkingQueries.target_for(_actor)
	if not NpcStalkingQueries.eligible(_actor, _person, player):
		return FAILURE
	var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
	_sequence = state.episode_sequence
	if NpcStalkingSolver.observed(_actor, player, _actor.global_position, state.rule):
		return FAILURE
	var now: int = GameTimeQueries.current().elapsed_ticks
	var position: Vector3 = (player as Node as Node3D).global_position
	var initial: bool = not state.destination.is_finite()
	var moved: bool = position.distance_to(state.sampled_position) >= state.rule.replan_distance
	if initial or (moved and state.replans_left > 0 and now >= state.next_replan_tick):
		var destination: Vector3 = NpcStalkingSolver.destination(
			_actor,
			_person,
			player,
			state.rule,
			state.candidate_offset,
		)
		if not destination.is_finite():
			return FAILURE
		if not initial:
			state.replans_left -= 1
		state.destination = destination
		state.sampled_position = position
		var interval: int = GameTimeRules.duration_ticks(state.rule.replan_seconds)
		state.next_replan_tick = now + mini(interval, state.deadline_tick - now)
	if not _claim("Жуткий: скрытый ограниченный подход"):
		return FAILURE
	if _actor.global_position.distance_to(state.destination) <= state.rule.arrival_tolerance:
		_own_movement()
		NpcIntentArbiter.stop(_actor, intent_owner)
	else:
		_move(state.destination, state.rule.arrival_tolerance)
	state.approach_task_id = get_instance_id()
	return RUNNING
#endregion
