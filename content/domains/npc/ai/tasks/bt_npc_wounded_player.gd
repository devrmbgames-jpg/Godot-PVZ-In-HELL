@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Observes a visible wounded player while retaining service, blood and safety eligibility.


func _tick(_delta: float) -> Status:
	return SUCCESS if NpcFeedingTargetQueries.wounded_player_for(_actor) != null else FAILURE
