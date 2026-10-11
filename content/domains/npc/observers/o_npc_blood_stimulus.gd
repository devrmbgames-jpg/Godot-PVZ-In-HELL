extends Observer
## A committed blood spawn immediately reaches only live NPCs that can perceive it.
class_name O_NpcBloodStimulus


func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_BloodArea]).on_event(HazardSpawnResult.EVENT)


func each(_event: Variant, zone: Entity, payload: Variant = null) -> void:
	var result: HazardSpawnResult = payload as HazardSpawnResult
	if result == null or result.restored:
		return
	cmd.add_custom(_observe.bind(weakref(zone), zone.get_component(C_Hazard)))


func _observe(reference: WeakRef, captured: C_Hazard) -> void:
	var zone: E_BloodArea = reference.get_ref() as E_BloodArea
	if not NpcBloodQueries.valid_zone(zone) or zone.get_component(C_Hazard) != captured:
		return
	var receivers: Array[WeakRef] = []
	for entity: Entity in _world.query.with_all([
		C_NpcIdentity,
		C_ReceiverTraits,
		C_NpcAwareness,
		C_NpcDecision,
	]).with_none([C_Death]).enabled().execute():
		receivers.append(weakref(entity))
	for receiver: WeakRef in receivers:
		# A previous synchronous social fact may have retired the source or a later receiver.
		zone = reference.get_ref() as E_BloodArea
		var actor: E_DistrictNpc = receiver.get_ref() as E_DistrictNpc
		if not EntityAvailability.contains(actor, _world) or not NpcBloodQueries.valid_zone(zone):
			continue
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
		if (
			person == null or person.death_day != 0
			or not NpcPerceptionService.can_see_point(actor, zone.global_position, person, zone)
		):
			continue
		NpcBloodService.observe(actor, person, zone, true)
