@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Stops residual chase and requests the authored shot; combat cadence owns cooldown and effects.


#region Firing intent lifetime
func _exit() -> void:
	if _owns_movement and is_instance_valid(_actor):
		var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
		if decision != null and decision.active_task_id == get_instance_id():
			NpcIntentService.look_along_movement(_actor)
	super._exit()


func _tick(_delta: float) -> Status:
	if not _claim("Дальняя атака / перезарядка"):
		return FAILURE
	var state: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	var variant: int = NpcRangedPositionSolver.variant(state)
	var target: Entity = CombatQueries.target_for(_actor)
	_own_movement()
	NpcIntentArbiter.stop(_actor, intent_owner)
	NpcIntentService.watch(_actor, target, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	NpcAttackService.start(_actor, C_NpcCombat.Kind.RANGED, variant)
	return RUNNING
#endregion
