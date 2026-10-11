@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Vampire blood attraction is eligible only through the perceived live Relationship.


func _tick(_delta: float) -> Status:
	return SUCCESS if NpcBloodQueries.calmed(_actor) else FAILURE
