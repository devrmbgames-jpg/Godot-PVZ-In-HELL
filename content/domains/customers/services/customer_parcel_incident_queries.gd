extends RefCounted
## Read-only incident, policy and stable endpoint lookup for wrong-parcel operations.
class_name CustomerParcelIncidentQueries


#region Stable pair and authored reaction
static func find(npc_id: StringName, package_id: String) -> CustomerParcelIncident:
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow != null:
		for incident: CustomerParcelIncident in flow.parcel_incidents:
			if incident.npc_id == npc_id and incident.package_id == package_id:
				return incident
	return null


## Checks only this receiver/parcel; the rightful receiver and ordinary manipulation stay free.
static func blocked(visit: CustomerVisit, parcel: Entity) -> bool:
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var incident: CustomerParcelIncident = find(visit.customer_id, identity.package_id)
	return (
		incident != null
		and (
			incident.phase == CustomerParcelIncident.Phase.HELD
			or GameTimeQueries.current().elapsed_ticks < incident.next_eligible_tick
		)
	)


static func rule_for(customer: Entity) -> DEF_NpcParcelReaction:
	var identity: C_NpcIdentity = customer.get_component(C_NpcIdentity) as C_NpcIdentity
	if identity == null:
		return null
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	if person != null:
		for capability: DEF_NpcTrait in person.rules_for():
			if capability is DEF_NpcParcelReaction:
				return capability as DEF_NpcParcelReaction
	return null


static func parcel_for(package_id: String) -> Entity:
	for entity: Entity in ECS.world.query.with_all([C_Package]).execute():
		if (entity.get_component(C_Package) as C_Package).package_id == package_id:
			return entity
	return null
#endregion
