extends RefCounted
## Explicit intimidation transaction; the existing incident journal owns the one committed choice.
class_name CustomerParcelDemandService

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")
const DEMAND = REACTIONS.DemandOutcome


#region Single demand and physical return
## True means the new choice committed, or a previously committed RETURN physically completed.
## A new RETURN without a safe destination stays HELD and can be claimed later without rerolling.
static func demand(actor: Entity, customer: E_DistrictNpc) -> bool:
	var incident: CustomerParcelIncident = CustomerParcelDemandQueries.available(actor, customer)
	if incident == null:
		return false
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var parcel: Entity = GrabQueries.held_in_slot(customer, C_Grabbable.HoldSlot.CARRY)
	var newly_committed: bool = incident.demand_outcome == DEMAND.NONE
	if newly_committed:
		var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
		var now: int = GameTimeQueries.current().elapsed_ticks
		var latest_tick: int = CustomerParcelIncidentService.MAX_COUNTER
		latest_tick -= CustomerParcelIncidentService.BLOCK_TICKS
		if not is_finite(strength.value) or now > latest_tick:
			return false
		var random: RandomNumberGenerator = GameTimeQueries.decision(
			String(incident.npc_id),
			DayPhaseQueries.current().day_index,
			"customer/parcel-demand/" + incident.package_id,
			incident.sequence,
		)
		incident.demand_strength = strength.value
		incident.demand_roll = random.randf()
		incident.demand_outcome = REACTIONS.choose_demand(
			incident.demand_strength,
			incident.demand_roll,
		)
		incident.demand_tick = now
	# No callback can observe half a demand or reenter the physical transfer.
	flow.parcel_reaction_in_progress = true
	var completed: bool = false
	if incident.demand_outcome == DEMAND.ATTACK:
		NpcSocialService.escalate_parcel_demand(
			customer,
			actor,
			StringName("parcel-demand/%d" % incident.sequence),
		)
	else:
		completed = _return_parcel(actor, customer, parcel, incident, flow)
		if newly_committed and not completed and GrabQueries.holder_available(customer):
			customer.show_message("Забирай. Освободи руки или место рядом.")
	flow.parcel_reaction_in_progress = false
	return newly_committed or completed


static func _return_parcel(
	actor: Entity,
	customer: E_DistrictNpc,
	parcel: Entity,
	incident: CustomerParcelIncident,
	flow: C_CustomerFlow,
) -> bool:
	var body: RigidBody3D = GrabQueries.physical_body(parcel)
	var destination: ItemPlacementSolver.Result = ItemPlacementSolver.Result.new()
	if not CustomerParcelDemandQueries.can_receive(actor, parcel):
		destination = CustomerParcelDemandGeometry.floor_destination(actor, customer, body)
		if not destination.available:
			return false
	var world: World = ECS.world
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	GrabReleaseService.release(customer, parcel, false)
	# Release publishes callbacks; preserve replacement ownership and recheck the full gate.
	if (
		ECS.world != world or CustomerFlowQueries.current() != flow
		or not EntityAvailability.contains(parcel, world)
		or parcel.get_component(C_Package) != identity or identity.package_id != incident.package_id
		or GrabQueries.physical_body(parcel) != body
		or GrabQueries.held_relationship(parcel) != null
		or not CustomerParcelDemandQueries.participants_available(actor, customer)
		or not CustomerParcelDemandQueries.contact_available(customer, incident)
		or not flow.parcel_incidents.has(incident) or incident.demand_outcome != DEMAND.RETURN
		or not CustomerParcelDemandQueries.parcel_available(parcel)
		or not CustomerParcelDemandGeometry.reachable(actor, customer, parcel)
	):
		return false
	if CustomerParcelDemandQueries.can_receive(actor, parcel):
		var binding: Relationship = Relationship.new(R_HeldBy.new(), actor)
		parcel.add_relationship(binding)
		return (
			ECS.world == world and EntityAvailability.contains(parcel, world)
			and parcel.relationships.has(binding)
			and (binding.relation as R_HeldBy).lifecycle_applied
		)
	# A callback may have occupied the player slots or changed the physical space.
	destination = CustomerParcelDemandGeometry.floor_destination(actor, customer, body)
	if not destination.available:
		# A release callback occupied the destination; keep the committed return physically pending.
		var pending: Relationship = Relationship.new(R_HeldBy.new(), customer)
		parcel.add_relationship(pending)
		if (
			ECS.world == world and EntityAvailability.contains(parcel, world)
			and parcel.relationships.has(pending)
			and (pending.relation as R_HeldBy).lifecycle_applied
		):
			incident.phase = CustomerParcelIncident.Phase.HELD
		return false
	# One-shot synchronization to the queried pose; normal physics resumes immediately.
	body.global_transform = destination.pose
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	body.sleeping = false
	return true
#endregion
