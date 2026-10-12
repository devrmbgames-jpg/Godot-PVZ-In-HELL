@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Observes optional local light discomfort without issuing an emergency reaction.


func _tick(_delta: float) -> Status:
	return SUCCESS if NpcLightComfortSolver.available(_actor, _person) else FAILURE
