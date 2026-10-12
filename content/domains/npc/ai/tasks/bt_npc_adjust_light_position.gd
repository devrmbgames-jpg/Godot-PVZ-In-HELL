@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Walks to one comfortable authored point; base action cleanup owns interruption of the request.

var _destination_id: StringName = &""


#region Local native movement
func _enter() -> void:
	super._enter()
	_destination_id = &""


func _tick(_delta: float) -> Status:
	var rule: DEF_NpcLightComfort = NpcLightComfortSolver.rule_for(_person)
	if (
		not NpcLightComfortSolver.available(_actor, _person)
		or not _claim("Сменить освещённую позицию")
	):
		return FAILURE
	if _destination_id.is_empty():
		_destination_id = NpcLightComfortSolver.destination_for(_actor, _person, rule)
	if _destination_id.is_empty():
		return FAILURE
	var destination: Vector3 = NpcPopulationQueries.position_for(_destination_id, true)
	if (
		not destination.is_finite()
		or _actor.global_position.distance_to(destination) > rule.search_radius
		or NpcLightingService.exposure_at(
			destination + Vector3.UP * NpcPerceptionService.TORSO_HEIGHT,
		)
		> rule.comfortable_threshold
	):
		return FAILURE
	if _actor.global_position.distance_to(destination) <= NpcDecisionService.ARRIVAL_DISTANCE:
		return SUCCESS
	var intent: C_NpcIntent = _intent()
	if (
		_owns_movement and intent.navigation_blocked
		and intent.navigation_task_id == get_instance_id()
		and intent.navigation_generation == intent.movement_generation
	):
		return FAILURE
	# A stopped owned request belongs to route abandonment; do not restart it in place.
	if _owns_movement and not intent.movement_active:
		return FAILURE
	if not _owns_movement:
		_move(destination, NpcDecisionService.ARRIVAL_DISTANCE)
	return RUNNING
#endregion
