@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Reads camera angle and distance; the tree chooses repositioning instead of observation.


#region Observation position guard
func _tick(_delta: float) -> Status:
	var player: Entity = NpcGazeAversionSolver.visible_player(_actor)
	if player == null:
		return FAILURE
	var camera: Camera3D = NpcGazeAversionSolver.camera_for(player)
	var rule: DEF_NpcGazeAversion = (
		_person.rule_for(DEF_NpcTrait.Kind.GAZE_AVERSION) as DEF_NpcGazeAversion
	)
	return SUCCESS if camera != null \
			and not NpcGazeAversionSolver.safe_position(
		_actor.global_position,
		player,
		camera,
		rule,
	) \
			else FAILURE
#endregion
