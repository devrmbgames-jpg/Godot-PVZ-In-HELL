@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Следит только за воспринимаемым участником активного разговора.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Разговор"):
		return FAILURE
	NpcIntentArbiter.stop(_actor, intent_owner)
	var participant: Entity = NpcDialogueService.participant(_actor)
	if participant != null and NpcPerceptionService.can_see(_actor, participant, _person.profile):
		NpcIntentService.watch(_actor, participant, Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	return RUNNING

#endregion
