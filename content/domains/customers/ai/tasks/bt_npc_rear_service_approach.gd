@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Executes one fixed hidden rear destination within the existing service approach clock.

var _sequence: int = 0
var _reached: bool = false


#region Bounded movement lifecycle
func _enter() -> void:
	super._enter()
	_sequence = 0
	_reached = false


func _exit() -> void:
	if is_instance_valid(_actor):
		var agent: C_CustomerAgent = _actor.get_component(C_CustomerAgent) as C_CustomerAgent
		if (
			agent != null and _sequence > 0
			and agent.stalking_sequence == _sequence and not _reached
		):
			CustomerStalkingBindings.release(_actor)
	super._exit()


func _tick(_delta: float) -> Status:
	var player: Entity = CustomerStalkingQueries.target_for(_actor)
	if not CustomerStalkingQueries.active(_actor, player):
		return FAILURE
	var agent: C_CustomerAgent = _service()
	var state: C_NpcStalking = _actor.get_component(C_NpcStalking) as C_NpcStalking
	_sequence = agent.stalking_sequence
	if NpcStalkingSolver.observed(_actor, player, _actor.global_position, state.rule):
		return FAILURE
	if not _claim("Жуткий: ограниченный сервисный обход"):
		return FAILURE
	var intent: C_NpcIntent = _intent()
	if (
		intent.navigation_generation == intent.movement_generation
		and intent.navigation_task_id == get_instance_id() and intent.navigation_blocked
	):
		return FAILURE
	if _actor.global_position.distance_to(agent.stalking_destination) <= state \
			.rule \
			.arrival_tolerance:
		if _actor.global_position.distance_to((player as Node as Node3D).global_position) \
				>= NpcStalkingRules.SUCCESS_DISTANCE:
			return FAILURE
		_reached = true
		return SUCCESS
	_move(agent.stalking_destination, state.rule.arrival_tolerance)
	NpcStalkingService.claim_service_motion(_actor, get_instance_id())
	return RUNNING
#endregion
