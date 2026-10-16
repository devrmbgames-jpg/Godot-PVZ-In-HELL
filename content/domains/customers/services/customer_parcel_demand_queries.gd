extends RefCounted
## Reads the actual stolen grip and eligibility without reserving a role or changing its clock.
class_name CustomerParcelDemandQueries

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")


#region Actual appropriation and participants
## A committed RETURN remains claimable; ATTACK can never be invoked again for this incident.
static func available(actor: Entity, customer: E_DistrictNpc) -> CustomerParcelIncident:
	if not participants_available(actor, customer):
		return null
	return _available(actor, customer)


## Reads a live conversation without treating its modal presentation as a physical refusal.
## Actual execution still uses available() after the dialogue releases its input capture.
static func available_in_dialogue(actor: Entity, customer: E_DistrictNpc) -> CustomerParcelIncident:
	if (
		NpcDialogueService.participant(customer) != actor
		or not _physical_participants_available(actor, customer)
	):
		return null
	return _available(actor, customer)


static func _available(actor: Entity, customer: E_DistrictNpc) -> CustomerParcelIncident:
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow == null or flow.parcel_reaction_in_progress:
		return null
	var parcel: Entity = GrabQueries.held_in_slot(customer, C_Grabbable.HoldSlot.CARRY)
	if parcel == null or not parcel.has_component(C_Package):
		return null
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var npc: C_NpcIdentity = customer.get_component(C_NpcIdentity) as C_NpcIdentity
	var incident: CustomerParcelIncident = CustomerParcelIncidentQueries.find(
		npc.npc_id,
		identity.package_id,
	)
	if (
		incident == null or incident.phase != CustomerParcelIncident.Phase.HELD
		or incident.outcome != REACTIONS.Outcome.KEEP or not contact_available(customer, incident)
		or incident.demand_outcome
		not in [REACTIONS.DemandOutcome.NONE, REACTIONS.DemandOutcome.RETURN]
		or not parcel_available(parcel)
		or not CustomerParcelDemandGeometry.reachable(actor, customer, parcel)
	):
		return null
	var grip: Relationship = GrabQueries.held_relationship(parcel)
	if grip == null or grip.target != customer or not (grip.relation as R_HeldBy).lifecycle_applied:
		return null
	return incident


## The existing service phase clock bounds the demand window; demands never reset or reserve it.
static func contact_available(customer: E_DistrictNpc, incident: CustomerParcelIncident) -> bool:
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(incident.visit_id)
	var identity: C_NpcIdentity = customer.get_component(C_NpcIdentity) as C_NpcIdentity
	if (
		agent == null or visit == null or visit.definition == null
		or visit.finished or agent.visit_id != incident.visit_id
		or visit.customer_id != incident.npc_id or identity.npc_id != incident.npc_id
	):
		return false
	var duration: float = 0.0
	match agent.phase:
		C_CustomerAgent.Phase.WAITING:
			duration = visit.definition.greeting_seconds
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, C_CustomerAgent.Phase.DIALOGUE:
			duration = visit.definition.patience_seconds
		C_CustomerAgent.Phase.RECEIVING:
			duration = visit.definition.receiving_seconds
		C_CustomerAgent.Phase.LEAVING:
			duration = maxf(DEF_Customer.MINIMUM_LEAVING_SECONDS, visit.definition.leaving_seconds)
	return is_finite(duration) and duration > 0.0 and agent.elapsed < duration


## Explicit demand commands have the same physical/control gate as the contextual action.
static func participants_available(actor: Entity, customer: E_DistrictNpc) -> bool:
	return (
		InteractionControlFocus.current(actor) <= InteractionControlFocus.Priority.CARRY
		and _physical_participants_available(actor, customer)
	)


static func _physical_participants_available(actor: Entity, customer: E_DistrictNpc) -> bool:
	if (
		not GrabQueries.holder_available(actor) or not GrabQueries.holder_available(customer)
		or not actor.has_component(C_PlayerInputController) or actor.has_component(C_Death)
		or customer.has_component(C_Death) or (customer as Node).get_tree().paused
		or bool(Console.is_visible())
		or CombatQueries.target_for(customer) != null or CombatQueries.target_for(actor) != null
	):
		return false
	var awareness: C_NpcAwareness = customer.get_component(C_NpcAwareness) as C_NpcAwareness
	var rule: DEF_NpcParcelReaction = CustomerParcelIncidentQueries.rule_for(customer)
	return (
		awareness != null and not awareness.fleeing and not NpcBloodQueries.calmed(customer)
		and actor.has_component(C_Strength) and actor.has_component(C_GrabControl)
		and actor.has_component(C_CarryLoad) and GrabQueries.hold_anchor(actor) != null
		and rule != null and rule.mode == DEF_NpcParcelReaction.Mode.TAKE_OR_THROW
		and rule.take_probability > 0.0
	)


## Grips alone cannot authorize returning a destroyed, slotted or inspected package.
static func parcel_available(parcel: Entity) -> bool:
	if not GrabQueries.entity_available(parcel) or parcel.has_component(C_Death):
		return false
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	var interactable: C_Interactable = parcel.get_component(C_Interactable) as C_Interactable
	return (
		state != null and state.damage != C_PackageState.Damage.DESTROYED
		and (interactable == null or interactable.enabled)
		and PhysicalSlotService.relationship(parcel) == null
		and CustomerInspectionQueries.owner_for(parcel) == null
		and GrabQueries.physical_body(parcel) != null
		and not GrabQueries.physical_body(parcel).freeze
	)


## A return never replaces anything in the player's native hand or Carry slots.
static func can_receive(actor: Entity, parcel: Entity) -> bool:
	for slot: int in 3:
		if GrabQueries.held_in_slot(actor, slot) != null:
			return false
	return (
		GrabQueries.can_carry_body(
			GrabQueries.physical_body(parcel),
			actor.get_component(C_Strength) as C_Strength,
		)
		and GrabQueries.profile_slot_allowed(
			GrabQueries.profile_for(parcel),
			C_Grabbable.HoldSlot.CARRY,
		)
	)
#endregion
