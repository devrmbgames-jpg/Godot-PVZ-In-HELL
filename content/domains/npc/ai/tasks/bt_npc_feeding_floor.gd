@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Observes the feeding floor only for the currently visible bound target.


func _tick(_delta: float) -> Status:
	return SUCCESS if NpcFeedingTargetQueries.target_at_floor(_actor) else FAILURE
