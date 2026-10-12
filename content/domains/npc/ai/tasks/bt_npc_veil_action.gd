@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Shared ownership/cleanup for narrow cloud and concealment leaves.


#region Native leaf lifecycle
func _exit() -> void:
	if is_instance_valid(_actor):
		NpcVeilService.release(_actor, get_instance_id())
	super._exit()


func _claim_form(form: C_NpcVeil.Form, behavior: String) -> bool:
	if NpcGazeQueries.frozen(_actor) or not _claim(behavior):
		return false
	_own_movement()
	return NpcVeilService.claim(_actor, form, get_instance_id())


## A native route failure or abandonment ends this form before the cooldown retries.
func _route_abandoned() -> bool:
	if not _owns_movement:
		return false
	var intent: C_NpcIntent = _intent()
	return (
		not intent.movement_active
		or (
			intent.navigation_blocked and intent.navigation_task_id == get_instance_id()
			and intent.navigation_generation == intent.movement_generation
		)
	)
#endregion
