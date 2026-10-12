extends System
## Samples physical toy exposure before cadence; the native tree alone commits the attack.
class_name S_CustomerToyWitness


#region Scheduling and sampling
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase], Runs.Before: [S_NpcCadence] }


func query() -> QueryBuilder:
	return q.with_all([C_NpcPride, C_NpcIdentity, C_NpcDecision]).with_none([C_Death]).enabled()


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var pride: C_NpcPride = entity.get_component(C_NpcPride) as C_NpcPride
		if pride.rule != null:
			cmd.add_custom(_sample.bind(weakref(entity), pride))


func _sample(actor_reference: WeakRef, captured: C_NpcPride) -> void:
	var actor: E_DistrictNpc = actor_reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(actor, _world) or actor.has_component(C_Death)
		or actor.get_component(C_NpcPride) != captured or captured.rule == null
	):
		return
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var player: Entity = _world.query.with_all([C_PlayerInputController]).enabled().execute_one()
	var exposed: String = CustomerToyExposureQueries.exposed_toy_id(
		actor,
		player,
		person,
		captured.rule,
	)
	if captured.exposed_toy_id == exposed:
		return
	captured.exposed_toy_id = exposed
	if not exposed.is_empty():
		NpcDecisionService.request_wake(actor, &"toy_witnessed", true)
#endregion
