extends RefCounted
## Commits one wrong-parcel incident before explicit grip, throw, damage or speech operations.
class_name CustomerParcelIncidentService

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")

const OUTCOME = REACTIONS.Outcome

const BLOCK_TICKS: int = 180 * GameTimeRules.TICKS_PER_SECOND
const MAX_INCIDENTS: int = 4096
const MAX_COUNTER: int = 9223372036854775807


#region Recognition transaction
## Revalidates the exact offer; false means no new recognition and must not produce a message.
static func react(offer: CustomerParcelOffer, automatic: bool) -> bool:
	var check: PackageDeliveryCheck = CustomerHandoffService.evaluate_offer(offer, automatic)
	if check.result != PackageDeliveryCheck.Result.WRONG_PACKAGE:
		return false
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow.parcel_reaction_in_progress or offer.visit.customer_id.is_empty():
		return false
	if CustomerParcelIncidentQueries.blocked(offer.visit, offer.parcel):
		return false
	var identity: C_Package = offer.parcel.get_component(C_Package) as C_Package
	var contents: C_PackageContents = (
		offer.parcel.get_component(C_PackageContents) as C_PackageContents
	)
	var item: DEF_InventoryItem = PackagePayloadRules.remaining_item(identity.definition, contents)
	var holy: bool = (
		item != null and item.receiver_effect != null
		and item.receiver_effect.alignment == DEF_ReceiverEffect.Alignment.HOLY
	)
	var rule: DEF_NpcParcelReaction = CustomerParcelIncidentQueries.rule_for(offer.customer)
	var now: int = GameTimeQueries.current().elapsed_ticks
	if now > MAX_COUNTER - BLOCK_TICKS or flow.parcel_incident_sequence >= MAX_COUNTER:
		return false
	_prune_expired(flow, now)
	if flow.parcel_incidents.size() >= MAX_INCIDENTS:
		return false
	var random: RandomNumberGenerator = GameTimeQueries.decision(
		String(offer.visit.customer_id),
		DayPhaseQueries.current().day_index,
		"customer/parcel/" + identity.package_id,
		flow.parcel_incident_sequence,
	)
	var outcome: REACTIONS.Outcome = REACTIONS.choose(
		rule,
		holy,
		item != null and item.destroyed_by_fire,
		random.randf(),
		random.randf(),
	)
	if outcome == OUTCOME.INVALID:
		return false
	var incident: CustomerParcelIncident = CustomerParcelIncident.new()
	incident.sequence = flow.parcel_incident_sequence
	incident.npc_id = offer.visit.customer_id
	incident.package_id = identity.package_id
	incident.visit_id = offer.visit.visit_id
	incident.outcome = outcome
	incident.created_tick = now
	incident.next_eligible_tick = now + BLOCK_TICKS
	# The choice/block precede every callback. A save cannot observe a half-applied reaction.
	flow.parcel_reaction_in_progress = true
	flow.parcel_incident_sequence += 1
	flow.parcel_incidents.append(incident)
	_apply(offer, incident, rule, automatic)
	flow.parcel_reaction_in_progress = false
	return true


static func _prune_expired(flow: C_CustomerFlow, now: int) -> void:
	for index: int in range(flow.parcel_incidents.size() - 1, -1, -1):
		var incident: CustomerParcelIncident = flow.parcel_incidents[index]
		if (
			incident.phase != CustomerParcelIncident.Phase.HELD
			and now >= incident.next_eligible_tick
		):
			flow.parcel_incidents.remove_at(index)


static func _apply(
	offer: CustomerParcelOffer,
	incident: CustomerParcelIncident,
	rule: DEF_NpcParcelReaction,
	automatic: bool,
) -> void:
	match incident.outcome:
		OUTCOME.KEEP:
			if _take(offer, automatic):
				incident.phase = CustomerParcelIncident.Phase.HELD
				offer.customer.show_message("Спасибо за подарок.")
				return
		OUTCOME.THROW_AT_PLAYER, OUTCOME.THROW_ASIDE:
			var direction: Vector3 = (offer.actor as Node as Node3D).global_position - (
				offer.parcel as Node as Node3D
			).global_position
			if incident.outcome == OUTCOME.THROW_ASIDE:
				direction = CustomerHandoffGeometry.clear_side_direction(
					GrabQueries.physical_body(offer.parcel),
					direction,
					offer.customer,
					offer.actor,
				)
			if not direction.is_zero_approx() and _take(offer, automatic):
				GrabService.throw_in_direction(offer.customer, offer.parcel, direction)
		OUTCOME.BURN, OUTCOME.DAMAGE:
			var request: DamageRequest = DamageRequest.new()
			request.target = offer.parcel
			request.source = offer.customer
			request.instigator = offer.customer
			request.instigator_id = offer.customer.id
			request.incident_id = StringName("parcel-reaction/%d" % incident.sequence)
			request.damage_type = DamageRequest.Type.FIRE
			var health: C_Health = offer.parcel.get_component(C_Health) as C_Health
			var burn: bool = incident.outcome == OUTCOME.BURN
			request.amount = health.current if burn else rule.damage_amount
			DamageRequestService.submit(request)
	if EntityAvailability.contains(offer.customer, offer.world):
		offer.customer.show_message("Это не моя посылка.")


static func _can_take(offer: CustomerParcelOffer) -> bool:
	if GrabQueries.held_in_slot(offer.customer, C_Grabbable.HoldSlot.CARRY) != null:
		return false
	var body: RigidBody3D = GrabQueries.physical_body(offer.parcel)
	var strength: C_Strength = offer.customer.get_component(C_Strength) as C_Strength
	if not GrabQueries.can_carry_body(body, strength):
		return false
	return GrabQueries.profile_slot_allowed(
		GrabQueries.profile_for(offer.parcel),
		C_Grabbable.HoldSlot.CARRY,
	)


static func _take(offer: CustomerParcelOffer, automatic: bool) -> bool:
	if not _can_take(offer):
		return false
	var identity: C_Package = offer.parcel.get_component(C_Package) as C_Package
	var package_id: String = identity.package_id
	var body: RigidBody3D = GrabQueries.physical_body(offer.parcel)
	var customer_id: StringName = offer.visit.customer_id
	var visit_id: StringName = offer.visit.visit_id
	if offer.source == CustomerParcelOffer.Source.HELD:
		GrabReleaseService.release(offer.actor, offer.parcel)
	# Release publishes callbacks; recheck the full physical/role/assignment contract afterwards.
	var check: PackageDeliveryCheck = CustomerHandoffService.evaluate_released_offer(
		offer,
		automatic,
	)
	if (
		check.result != PackageDeliveryCheck.Result.WRONG_PACKAGE
		or offer.parcel.get_component(C_Package) != identity or identity.package_id != package_id
		or GrabQueries.physical_body(offer.parcel) != body or offer.visit.customer_id != customer_id
		or offer.visit.visit_id != visit_id or not _can_take(offer)
	):
		return false
	var binding: Relationship = Relationship.new(R_HeldBy.new(), offer.customer)
	offer.parcel.add_relationship(binding)
	return (
		offer.world == ECS.world and GrabQueries.holder_available(offer.customer)
		and EntityAvailability.contains(offer.parcel, offer.world)
		and offer.parcel.relationships.has(binding)
		and (binding.relation as R_HeldBy).lifecycle_applied
	)
#endregion


#region Discrete release and reconstruction
## Called by the relationship observer; a drop starts the pair deadline at the actual release.
static func grip_removed(parcel: Entity, binding: Relationship) -> void:
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow == null:
		return
	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	if identity == null:
		return
	for incident: CustomerParcelIncident in flow.parcel_incidents:
		if (
			incident.phase != CustomerParcelIncident.Phase.HELD
			or incident.package_id != identity.package_id
		):
			continue
		var holder: Entity = binding.target as Entity
		var npc: C_NpcIdentity = (
			holder.get_component(C_NpcIdentity) as C_NpcIdentity
			if is_instance_valid(holder)
			else null
		)
		if npc != null and npc.npc_id == incident.npc_id:
			incident.phase = CustomerParcelIncident.Phase.COMPLETED
			incident.next_eligible_tick = GameTimeQueries.current().elapsed_ticks + BLOCK_TICKS


## Restore suppresses observers; retire physical effects explicitly before passive field overlay.
static func release_for_restore() -> void:
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow == null:
		return
	for incident: CustomerParcelIncident in flow.parcel_incidents:
		if incident.phase == CustomerParcelIncident.Phase.HELD:
			var parcel: Entity = CustomerParcelIncidentQueries.parcel_for(incident.package_id)
			if parcel != null:
				var binding: Relationship = GrabQueries.held_relationship(parcel)
				if binding != null:
					GrabReleaseService.release(binding.target as Entity, parcel, false)


## Rebuild only committed appropriation; never replay choice, speech, impulse or damage.
static func restore_bindings() -> bool:
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow == null:
		return true
	flow.parcel_reaction_in_progress = false
	for incident: CustomerParcelIncident in flow.parcel_incidents:
		if incident.phase != CustomerParcelIncident.Phase.HELD:
			continue
		var holder: E_DistrictNpc = NpcPopulationQueries.body_for(incident.npc_id)
		var parcel: Entity = CustomerParcelIncidentQueries.parcel_for(incident.package_id)
		var old_binding: Relationship = GrabQueries.held_relationship(parcel)
		if old_binding != null:
			GrabReleaseService.release(old_binding.target as Entity, parcel, false)
		# Saved HELD excludes anchoring/slots and explicitly owns movable physical reconstruction.
		(GrabQueries.physical_body(parcel)).freeze = false
		var binding: Relationship = Relationship.new(R_HeldBy.new(), holder)
		parcel.add_relationship(binding)
		if not GrabService.grip_added(parcel, binding):
			parcel.remove_relationship(binding)
			return false
	return true
#endregion
