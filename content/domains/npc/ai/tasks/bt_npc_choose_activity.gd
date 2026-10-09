@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Назначает одну авторскую точку нового свободного занятия.


#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Выбрать прогулку"):
		return FAILURE
	var destination: DEF_DistrictPlace = NpcActivityService.choose(_actor, _person)
	if destination == null:
		return FAILURE
	# A preview without an eligible destination does not consume the durable decision sequence.
	_awareness.idle_elapsed = 0.0
	_person.activity_sequence += 1
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	decision.local_activity_id = destination.key
	NpcIntentArbiter.move_to(
		_actor,
		NpcActivityService.destination(destination),
		NpcDecisionService.ARRIVAL_DISTANCE,
		intent_owner,
	)
	return SUCCESS

#endregion
