@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Requests one safe side position; the native movement token cleans up every interruption.

var _destination: Vector3 = Vector3.INF


#region Safe observation movement lifecycle
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
	if not _claim("Отойти из взгляда"):
		return FAILURE
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	if player == null:
		return FAILURE
	var camera: Camera3D = NpcGazeAversionSolver.camera_for(player)
	if camera == null:
		return FAILURE
	var rule: DEF_NpcGazeAversion = (
		_person.rule_for(DEF_NpcTrait.Kind.GAZE_AVERSION) as DEF_NpcGazeAversion
	)
	if not _destination.is_finite() \
			or not NpcGazeAversionSolver.safe_position(_destination, player, camera, rule):
		_destination = NpcGazeAversionSolver.destination(_actor, _person, player, rule)
		if not _destination.is_finite():
			return FAILURE
		_move(_destination, NpcDecisionService.ARRIVAL_DISTANCE)
	NpcIntentService.watch(_actor, player, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	return SUCCESS if _intent().arrived else RUNNING
#endregion
