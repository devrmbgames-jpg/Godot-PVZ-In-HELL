extends RefCounted
## Closed incident semantics and native held endpoints; rejects before passive World mutation.
class_name CustomerParcelIncidentSnapshotRules

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")
const DEMAND = REACTIONS.DemandOutcome


#region Durable pair semantics
static func valid(
	components: Dictionary[String, Dictionary],
	records: Dictionary[String, Dictionary],
) -> bool:
	var flow: C_CustomerFlow = null
	var calendar: C_DayCycle = null
	var packages: Dictionary[String, String] = { }
	var npcs: Dictionary[StringName, String] = { }
	for key: String in components:
		var types: Dictionary = components[key]
		if types.has(C_CustomerFlow):
			if flow != null:
				return false
			flow = types[C_CustomerFlow] as C_CustomerFlow
		if types.has(C_DayCycle):
			calendar = types[C_DayCycle] as C_DayCycle
		if types.has(C_Package):
			packages[(types[C_Package] as C_Package).package_id] = key
		if types.has(C_NpcIdentity):
			npcs[(types[C_NpcIdentity] as C_NpcIdentity).npc_id] = key
	if flow == null:
		return true
	if (
		flow.parcel_incident_sequence < 1
		or flow.parcel_incidents.size() > CustomerParcelIncidentService.MAX_INCIDENTS
	):
		return false
	var sequences: Dictionary[int, bool] = { }
	var pairs: Dictionary[StringName, Dictionary] = { }
	var held_npcs: Dictionary[StringName, bool] = { }
	var held_packages: Dictionary[String, bool] = { }
	for incident: CustomerParcelIncident in flow.parcel_incidents:
		if incident == null or calendar == null:
			return false
		var now: int = calendar.clock.elapsed_ticks
		if (
			incident.sequence < 1 or incident.sequence >= flow.parcel_incident_sequence
			or sequences.has(incident.sequence) or incident.npc_id.is_empty()
			or incident.package_id.is_empty() or incident.visit_id.is_empty()
			or incident.outcome
			not in [
				CustomerParcelReactionRules.Outcome.REFUSE,
				CustomerParcelReactionRules.Outcome.KEEP,
				CustomerParcelReactionRules.Outcome.THROW_AT_PLAYER,
				CustomerParcelReactionRules.Outcome.THROW_ASIDE,
				CustomerParcelReactionRules.Outcome.BURN,
				CustomerParcelReactionRules.Outcome.DAMAGE,
			]
			or incident.phase
			not in [CustomerParcelIncident.Phase.COMPLETED, CustomerParcelIncident.Phase.HELD]
			or incident.created_tick < 0 or incident.created_tick > now
			or incident.next_eligible_tick < incident.created_tick
			or incident.next_eligible_tick - incident.created_tick
			< CustomerParcelIncidentService.BLOCK_TICKS
			or (
				incident.next_eligible_tick > now
				and incident.next_eligible_tick - now > CustomerParcelIncidentService.BLOCK_TICKS
			)
		):
			return false
		if not _valid_demand(incident, now):
			return false
		var package_pairs: Dictionary = pairs.get(incident.npc_id, { }) as Dictionary
		if package_pairs.has(incident.package_id):
			return false
		package_pairs[incident.package_id] = true
		pairs[incident.npc_id] = package_pairs
		sequences[incident.sequence] = true
		if incident.phase != CustomerParcelIncident.Phase.HELD:
			continue
		if (
			incident.outcome != CustomerParcelReactionRules.Outcome.KEEP
			or not packages.has(incident.package_id) or not npcs.has(incident.npc_id)
			or held_npcs.has(incident.npc_id) or held_packages.has(incident.package_id)
		):
			return false
		var npc_key: String = npcs[incident.npc_id]
		var parcel_key: String = packages[incident.package_id]
		var holder: Dictionary = components[npc_key]
		var payload: Dictionary = components[parcel_key]
		if (
			not bool(records[npc_key].enabled) or bool(records[npc_key].death)
			or not bool(records[parcel_key].enabled) or bool(records[parcel_key].death)
			or records[parcel_key].has("anchor")
			or not (records[parcel_key].links as Array).is_empty() or not holder.has(C_Strength)
			or not holder.has(C_Health) or not payload.has(C_PackageState)
			or (holder[C_Health] as C_Health).current <= 0.0
			or (payload[C_PackageState] as C_PackageState).damage == C_PackageState.Damage.DESTROYED
		):
			return false
		var identity: C_Package = payload[C_Package] as C_Package
		var contents: C_PackageContents = payload.get(C_PackageContents) as C_PackageContents
		var mass: float = PackageShipmentRules.mass_kg(
			identity.definition,
			contents,
			contents != null and contents.released,
		)
		if not CarryLoadPolicy.can_carry(mass, holder[C_Strength] as C_Strength):
			return false
		held_npcs[incident.npc_id] = true
		held_packages[incident.package_id] = true
	return true


static func _valid_demand(incident: CustomerParcelIncident, now: int) -> bool:
	if incident.demand_outcome == DEMAND.NONE:
		return (
			incident.demand_strength == 0.0 and incident.demand_roll == 0.0
			and incident.demand_tick == -1
		)
	if (
		incident.demand_outcome not in [DEMAND.ATTACK, DEMAND.RETURN]
		or incident.outcome != REACTIONS.Outcome.KEEP
		or incident.demand_tick < incident.created_tick or incident.demand_tick > now
		or (
			incident.phase == CustomerParcelIncident.Phase.COMPLETED
			and incident.next_eligible_tick - incident.demand_tick
			< CustomerParcelIncidentService.BLOCK_TICKS
		)
	):
		return false
	# Validate the captured facts, never current Strength or a new RNG sample.
	return REACTIONS.choose_demand(incident.demand_strength, incident.demand_roll) == (
		incident.demand_outcome
	)
#endregion


#region Detached native endpoint roles
## Called after native recipes are prepared, while every candidate is still unpublished.
static func valid_entities(records: Array, entities: Dictionary[String, Entity]) -> bool:
	var packages: Dictionary[String, Entity] = { }
	var flows: Array[C_CustomerFlow] = []
	for record: Dictionary in records:
		for saved: Dictionary in record.components:
			var script: Script = SaveDataCodec.component_script(String(saved.type))
			if script == C_Package:
				packages[String((saved.fields as Dictionary).package_id)] = entities[
					String(record.key)
				]
			elif script == C_CustomerFlow:
				var flow: C_CustomerFlow = C_CustomerFlow.new()
				if not SaveDataCodec.apply_fields(flow, saved.fields as Dictionary):
					return false
				flows.append(flow)
	for flow: C_CustomerFlow in flows:
		for incident: CustomerParcelIncident in flow.parcel_incidents:
			if incident.phase != CustomerParcelIncident.Phase.HELD:
				continue
			var holder: Entity = entities.get(String(incident.npc_id)) as Entity
			var parcel: Entity = packages.get(incident.package_id) as Entity
			if (
				not holder is E_DistrictNpc or not parcel is E_Package
				or not holder.get_node_or_null("HandoffAnchor") is Node3D
				or _component(holder, C_GrabControl) == null
				or _component(holder, C_CarryLoad) == null
			):
				return false
			var grabbable: C_Grabbable = _component(parcel, C_Grabbable) as C_Grabbable
			if grabbable != null and grabbable.allowed_hand_slots != 0:
				return false
	return true


static func _component(entity: Entity, script: Script) -> Component:
	var existing: Component = entity.get_component(script) as Component
	if existing != null:
		return existing
	for recipe: Component in entity.component_resources:
		if recipe.get_script() == script:
			return recipe
	return null
#endregion
