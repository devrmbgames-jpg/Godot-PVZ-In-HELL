@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Requests one safe navmesh firing position; physics owns movement and the task token owns cleanup.

var _destination: Vector3 = Vector3.INF


#region Ranged positioning lifetime
func _enter() -> void:
	super._enter()
	_destination = Vector3.INF


func _exit() -> void:
	if _owns_movement and is_instance_valid(_actor):
		var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
		if decision != null and decision.active_task_id == get_instance_id():
			NpcIntentService.look_along_movement(_actor)
	super._exit()


func _tick(_delta: float) -> Status:
	if not _claim("Держать дистанцию дальнего боя"):
		return FAILURE
	var state: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	var variant: int = NpcRangedPositionSolver.variant(state)
	var attack: DEF_NpcAttack = state.ranged_attacks[variant]
	var observed: Vector3 = _awareness.last_seen_position
	if not _destination.is_finite() \
			or not NpcRangedPositionSolver.positioned(_destination, observed, attack):
		_destination = NpcRangedPositionSolver.destination(_actor, _person, observed, attack)
		if not _destination.is_finite():
			return FAILURE
		_move(_destination, NpcRangedPositionSolver.POSITION_TOLERANCE)
	NpcIntentService.watch(
		_actor,
		CombatQueries.target_for(_actor),
		Vector3.UP * NpcPerceptionService.EYE_HEIGHT,
	)
	return RUNNING
#endregion
