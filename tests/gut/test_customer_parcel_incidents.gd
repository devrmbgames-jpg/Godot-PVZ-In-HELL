extends "res://tests/gut/test_customer_handoff.gd"
## Real wrong-offer commits, physical NPC ownership/throws and active-time pair idempotency.

const REACTIONS = preload("res://content/domains/customers/rules/customer_parcel_reaction_rules.gd")
const DEMAND = REACTIONS.DemandOutcome
const DEMAND_ACTION: DEF_InteractionAction = preload(
	"res://content/domains/customers/definitions/def_action_customer_parcel_demand.tres"
)
const SECOND_PARCEL: PackedScene = preload(
	"res://content/domains/packages/entities/package_a.tscn"
)
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
const TOY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
const HOLY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_holy_artifact.tres"
)

var _flow: C_CustomerFlow


## Retains only durable facts from destruction, after physical ownership cleanup.
class CaptureDestruction extends Observer:
	## Destroyed package IDs observed through the actual lifecycle channel.
	var package_ids: Array[String] = []
	## Captured attribution IDs; no borrowed actor survives the event.
	var actor_ids: Array[String] = []
	## Whether a physical grip still existed when each destruction fact arrived.
	var held: Array[bool] = []


	func query() -> QueryBuilder:
		return q.on_event(PackageLifecycleEvent.EVENT)


	func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
		var fact: PackageLifecycleEvent = payload as PackageLifecycleEvent
		if fact.kind != PackageLifecycleEvent.Kind.DESTROYED:
			return
		package_ids.append(fact.package_id)
		actor_ids.append(fact.actor_id)
		held.append(GrabQueries.held_relationship(entity) != null)


## Observes the actual synchronous release callback, not a manually toggled transaction flag.
class CaptureDuringRelease extends Observer:
	## Borrowed test root for the real snapshot operation.
	var capture_root: Node
	## Captured operation results, retained only for this test.
	var snapshots: Array[Dictionary] = []
	## Journal size visible inside the physical ownership transition.
	var committed_count: int = 0
	## Optional real release mutation used to exercise the post-callback offer gate.
	var on_release: Callable


	func query() -> QueryBuilder:
		return q.on_relationship_removed([R_HeldBy])


	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		if on_release.is_valid():
			on_release.call()
		committed_count = CustomerFlowQueries.current().parcel_incidents.size()
		snapshots.append(WorldSnapshotService.capture(capture_root, 1))


## Reads a snapshot inside native command execution, after its pending queue was detached.
class CaptureDuringDamage extends Observer:
	## Borrowed test root for capture and retained callback results.
	var capture_root: Node
	## Captures made while damage resolution still owns the native batch.
	var snapshots: Array[Dictionary] = []


	func query() -> QueryBuilder:
		return q.on_event(DamageResult.EVENT)


	func each(_event: Variant, _entity: Entity, _payload: Variant = null) -> void:
		snapshots.append(WorldSnapshotService.capture(capture_root, 1))


#region Real role and captured decision fixtures
func before_each() -> void:
	await super.before_each()
	_flow = CustomerFlowQueries.current()
	_world.add_observer(O_CustomerParcelIncidents.new())
	_visit.customer_id = &"npc/ordinary"
	_cycle.clock.elapsed_ticks = 1000


func _wrong_offer() -> CustomerParcelOffer:
	_visit.package_id = "other-required-parcel"
	for binding: Relationship in _parcel.relationships.duplicate():
		if binding.relation is R_AssignedTo:
			_parcel.remove_relationship(binding)
	return CustomerHandoffService.select_offer(_actor, _customer, _visit)


func _native_receiver(key: StringName) -> void:
	var district: C_District = C_District.new()
	district.definition = (
		load("res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	)
	district.people = NpcPopulationRules.initial_records(district.definition, 1, 0)
	var session: Entity = _world.query.with_all([C_CustomerFlow]).execute_one()
	session.add_component(district)
	var person: NpcRecord = null
	for candidate: NpcRecord in district.people:
		if candidate.profile.key == key:
			person = candidate
	assert_not_null(person)
	if person == null:
		return
	# World removal queues deletion; the old fixture must stop occluding this same-frame demand.
	(_customer as Node as PhysicsBody3D).collision_layer = 0
	_world.remove_entity(_customer)
	var actor: E_DistrictNpc = (
		load("res://content/domains/npc/entities/district_npc.tscn") as PackedScene
	).instantiate() as E_DistrictNpc
	actor.freeze = true
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		_world,
		String(person.npc_id),
	)
	NpcConstructionService.configure_context(context, person, district.definition)
	assert_true(EntityCompositionService.try_register(context))
	_customer = actor
	_agent = C_CustomerAgent.new()
	_agent.visit_id = _visit.visit_id
	_agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_customer.add_component(_agent)
	_visit.customer_id = person.npc_id
	(_actor as Node as Node3D).position.z = -2.0
	var anchor: Node3D = _customer.hold_anchor
	var position: Vector3 = anchor.global_position - anchor.global_basis.z * 0.35
	(_parcel as Node as Node3D).global_position = position


func _payload(item: DEF_InventoryItem) -> void:
	var contents: C_PackageContents = _parcel.get_component(C_PackageContents) as C_PackageContents
	contents.selected_item = item
	contents.quantity = 1
	contents.packing_profile = PackagePackingRules.choose(
		SUPPLY.packing_profiles,
		item.cargo_profile,
		1,
	)
	(_parcel as Node as RigidBody3D).mass = PackageContentsService.full_mass_kg(_parcel)


func _decision(
	outcome: REACTIONS.Outcome,
	demand: REACTIONS.DemandOutcome = DEMAND.NONE,
	strength: float = 5.0,
) -> void:
	var rule: DEF_NpcParcelReaction = CustomerParcelIncidentQueries.rule_for(_customer)
	var contents: C_PackageContents = _parcel.get_component(C_PackageContents) as C_PackageContents
	var item: DEF_InventoryItem = PackagePayloadRules.remaining_item(
		_parcel.package_definition,
		contents,
	)
	for sequence: int in range(1, 1000):
		var random: RandomNumberGenerator = GameTimeQueries.decision(
			String(_visit.customer_id),
			1,
			"customer/parcel/" + (_parcel.get_component(C_Package) as C_Package).package_id,
			sequence,
		)
		var selected: REACTIONS.Outcome = REACTIONS.choose(
			rule,
			item == HOLY,
			item != null and item.destroyed_by_fire,
			random.randf(),
			random.randf(),
		)
		if selected == outcome:
			if demand != DEMAND.NONE:
				var demand_random: RandomNumberGenerator = GameTimeQueries.decision(
					String(_visit.customer_id), 1,
					"customer/parcel-demand/" + (
						_parcel.get_component(C_Package) as C_Package
					).package_id,
					sequence,
				)
				if REACTIONS.choose_demand(strength, demand_random.randf()) != demand:
					continue
			_flow.parcel_incident_sequence = sequence
			return
	fail_test("Authored decision fixture has no requested outcome")


func _stolen_for_demand(outcome: REACTIONS.DemandOutcome) -> CustomerParcelIncident:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP, outcome)
	(_actor.get_component(C_Strength) as C_Strength).value = 5.0
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_true(
		CustomerParcelDemandQueries.participants_available(_actor, _customer as E_DistrictNpc),
		"Demand participants available",
	)
	assert_true(CustomerParcelDemandQueries.parcel_available(_parcel), "Demand parcel available")
	assert_true(
		CustomerParcelDemandGeometry.reachable(_actor, _customer as E_DistrictNpc, _parcel),
		"Demand physical reach available",
	)
	assert_not_null(CustomerParcelDemandQueries.available(_actor, _customer as E_DistrictNpc))
	return _flow.parcel_incidents[0]


func _obstacle(position: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	_world.add_child(body)
	return body


## Registers the stolen physical parcel and a separate, still-waiting rightful order.
func _rightful_order() -> CustomerVisit:
	var session: Entity = _world.query.with_all([C_CustomerFlow]).execute_one()
	session.add_component(C_Wallet.new())
	WalletService.current().policy = DEF_Economy.new()
	_world.add_observer(O_CustomerOutcomes.new())
	assert_eq(
		PackageRegistrationService.register_package(_parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	var rightful: CustomerVisit = CustomerVisit.new()
	rightful.visit_id = &"rightful/stolen-parcel"
	rightful.customer_id = &"fixture/rightful-recipient"
	rightful.package_id = (_parcel.get_component(C_Package) as C_Package).package_id
	rightful.package_history_id = (_parcel.get_component(C_Package) as C_Package).history_id
	rightful.definition = DEF_Customer.new()
	rightful.definition.healthy_satisfaction = 100
	rightful.definition.unresolved_complaint_probability = 1.0
	rightful.definition.max_followup_visits = 0
	rightful.payment = 100
	rightful.accounting_value = 100
	rightful.complaint_roll = 0.0
	_flow.visits.append(rightful)
	return rightful
#endregion


#region Recognition and physical outcomes
func test_wrong_refusal_commits_before_reentry_and_expires_at_180_active_seconds() -> void:
	var offer: CustomerParcelOffer = _wrong_offer()
	assert_not_null(offer)
	assert_eq(CustomerFlowService.confirm_offer(offer), PackageDeliveryCheck.Result.WRONG_PACKAGE)
	assert_eq(_flow.parcel_incidents.size(), 1)
	assert_eq(_flow.parcel_incident_sequence, 2)
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_null(CustomerHandoffService.select_offer(_actor, _customer, _visit, false))
	assert_false(CustomerParcelIncidentService.react(offer, false))
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(179.9)
	assert_null(CustomerHandoffService.select_offer(_actor, _customer, _visit))
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(0.1)
	assert_not_null(CustomerHandoffService.select_offer(_actor, _customer, _visit))
	assert_true(CustomerParcelIncidentService.react(offer, true))
	assert_eq(_flow.parcel_incidents.size(), 1)
	assert_eq(_flow.parcel_incident_sequence, 3)


func test_pair_block_does_not_block_the_actual_recipient_or_repeat_manual_speech() -> void:
	var offer: CustomerParcelOffer = _wrong_offer()
	assert_true(CustomerParcelIncidentService.react(offer, true))
	_customer.show_message("sentinel")
	CustomerFlowService.confirm_offer(offer, false)
	assert_eq((_customer.get_node("Message") as Label3D).text, "sentinel")
	_visit.package_id = (_parcel.get_component(C_Package) as C_Package).package_id
	CustomerParcelAssignment.bind_parcel(_customer, _visit)
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


func test_native_brute_keeps_one_actual_grip_without_resolving_its_own_order() -> void:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP)
	var offer: CustomerParcelOffer = _wrong_offer()
	assert_true(CustomerParcelIncidentService.react(offer, true))
	assert_null(GrabQueries.held_object(_actor))
	assert_same(GrabQueries.held_object(_customer), _parcel)
	assert_eq(_flow.parcel_incidents[0].phase, CustomerParcelIncident.Phase.HELD)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq((_customer.get_node("Message") as Label3D).text, "Спасибо за подарок.")
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(200.0)
	GrabReleaseService.release(_customer, _parcel)
	assert_eq(_flow.parcel_incidents[0].phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_eq(
		_flow.parcel_incidents[0].next_eligible_tick,
		_cycle.clock.elapsed_ticks + CustomerParcelIncidentService.BLOCK_TICKS,
	)


func test_disabling_the_thief_releases_the_real_parcel_without_settling_its_order() -> void:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP)
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(200.0)
	_world.disable_entity(_customer)
	_assert_retired_theft_keeps_the_unresolved_parcel()
	var deadline: int = _flow.parcel_incidents[0].next_eligible_tick
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(1.0)
	GrabReleaseService.entity_unavailable(_customer)
	assert_eq(_flow.parcel_incidents[0].next_eligible_tick, deadline)


func test_removing_the_thief_releases_the_real_parcel_without_settling_its_order() -> void:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP)
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(200.0)
	_world.remove_entity(_customer)
	_assert_retired_theft_keeps_the_unresolved_parcel()


func _assert_retired_theft_keeps_the_unresolved_parcel() -> void:
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_true(EntityAvailability.contains(_parcel, _world))
	assert_eq(_flow.parcel_incidents[0].phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_eq(
		_flow.parcel_incidents[0].next_eligible_tick,
		_cycle.clock.elapsed_ticks + CustomerParcelIncidentService.BLOCK_TICKS,
	)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_flow.parcel_incidents.size(), 1)
	assert_null(ThrowContext.relationship(_parcel))


func test_chain_throw_is_a_real_impulse_attributed_to_the_npc() -> void:
	_native_receiver(&"archetype/chain_devil")
	_decision(REACTIONS.Outcome.THROW_AT_PLAYER)
	var expected: Vector3 = (_actor as Node as Node3D).global_position - (
		_parcel as Node as Node3D
	).global_position
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_same(ThrowContext.relationship(_parcel).target, _customer)
	await get_tree().physics_frame
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	for step: int in 6:
		if body.linear_velocity.length_squared() > 0.0:
			break
		await get_tree().physics_frame
	assert_gt(body.linear_velocity.dot(expected), 0.0)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_holy_payload_is_thrown_sideways_instead_of_kept_or_aimed_at_player() -> void:
	_native_receiver(&"archetype/brute")
	_payload(HOLY)
	var to_player: Vector3 = (_actor as Node as Node3D).global_position - (
		_parcel as Node as Node3D
	).global_position
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_eq(_flow.parcel_incidents[0].outcome, REACTIONS.Outcome.THROW_ASIDE)
	assert_null(GrabQueries.held_relationship(_parcel))
	await get_tree().physics_frame
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	for step: int in 6:
		if body.linear_velocity.length_squared() > 0.0:
			break
		await get_tree().physics_frame
	var velocity: Vector3 = body.linear_velocity
	assert_gt(velocity.length(), 0.0)
	assert_almost_eq(
		velocity.normalized().dot(to_player.slide(Vector3.UP).normalized()),
		0.0,
		0.001,
	)


func test_fire_burn_uses_actual_damage_and_consumes_the_real_selected_payload() -> void:
	_native_receiver(&"archetype/fire_elemental")
	_payload(TOY)
	_decision(REACTIONS.Outcome.BURN)
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_PackageDamage.new())
	_world.add_observer(O_PackageDestruction.new())
	var contents: C_PackageContents = _parcel.get_component(C_PackageContents) as C_PackageContents
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_true(contents.released)
	assert_eq(_world.query.with_all([C_Package]).execute().size(), 0)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(_flow.parcel_reaction_in_progress)


func test_fire_damage_uses_authored_hp_amount_and_does_not_consume_solid_contents() -> void:
	_native_receiver(&"archetype/fire_elemental")
	_payload(TOY)
	_decision(REACTIONS.Outcome.DAMAGE)
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_PackageDamage.new())
	var health: C_Health = _parcel.get_component(C_Health) as C_Health
	var previous: float = health.current
	var rule: DEF_NpcParcelReaction = CustomerParcelIncidentQueries.rule_for(_customer)
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_eq(health.current, previous - rule.damage_amount)
	assert_false(PackageContentsService.is_empty(_parcel))


func test_release_callback_sees_committed_choice_and_cannot_capture_half_a_reaction() -> void:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	_world.add_observer(observer)
	assert_false(WorldSnapshotService.capture(self, 1).is_empty())
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_eq(observer.committed_count, 1)
	assert_eq(observer.snapshots.size(), 1)
	if not observer.snapshots.is_empty():
		assert_true(observer.snapshots[0].is_empty())
	assert_false(_flow.parcel_reaction_in_progress)


func test_keep_rechecks_reach_after_real_player_release_callback() -> void:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		(_parcel as Node as Node3D).global_position += Vector3(10.0, 0.0, 0.0)
	_world.add_observer(observer)
	var offer: CustomerParcelOffer = _wrong_offer()
	assert_true(CustomerParcelIncidentService.react(offer, true))
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_eq(_flow.parcel_incidents.size(), 1)
	assert_eq(_flow.parcel_incidents[0].phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_false(CustomerParcelIncidentService.react(offer, true))
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_keep_rechecks_wrong_assignment_after_real_player_release_callback() -> void:
	_native_receiver(&"archetype/brute")
	_decision(REACTIONS.Outcome.KEEP)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		_visit.package_id = (_parcel.get_component(C_Package) as C_Package).package_id
		CustomerParcelAssignment.bind_parcel(_customer, _visit)
	_world.add_observer(observer)
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_eq(_flow.parcel_incidents.size(), 1)
	assert_eq(_flow.parcel_incidents[0].phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_manual_fire_excludes_snapshot_until_damage_and_package_commands_complete() -> void:
	_native_receiver(&"archetype/fire_elemental")
	_payload(TOY)
	_decision(REACTIONS.Outcome.DAMAGE)
	var damage: O_Damage = O_Damage.new()
	damage.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(damage)
	var capture: CaptureDuringDamage = CaptureDuringDamage.new()
	capture.capture_root = self
	_world.add_observer(capture)
	var package_damage: O_PackageDamage = O_PackageDamage.new()
	package_damage.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(package_damage)
	var health: C_Health = _parcel.get_component(C_Health) as C_Health
	var previous: float = health.current
	var amount: float = CustomerParcelIncidentQueries.rule_for(_customer).damage_amount
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_false(_flow.parcel_reaction_in_progress)
	assert_eq(health.current, previous)
	assert_true(WorldSnapshotService.capture(self, 1).is_empty())
	damage.cmd.execute()
	assert_eq(capture.snapshots.size(), 1)
	assert_true(capture.snapshots[0].is_empty())
	assert_false(damage.has_pending_commands())
	assert_true(package_damage.has_pending_commands())
	assert_true(WorldSnapshotService.capture(self, 1).is_empty())
	assert_true(CommandBufferBarrier.drain_pending(_world))
	assert_eq(health.current, previous - amount)
	assert_false(WorldSnapshotService.capture(self, 1).is_empty())
	assert_true(CommandBufferBarrier.drain_pending(_world))
	assert_eq(health.current, previous - amount)
	assert_eq(_flow.parcel_incidents.size(), 1)


func test_manual_burn_blocks_capture_until_the_actual_payload_is_consumed_once() -> void:
	_native_receiver(&"archetype/fire_elemental")
	_payload(TOY)
	_decision(REACTIONS.Outcome.BURN)
	for observer: Observer in [O_Damage.new(), O_PackageDamage.new(), O_PackageDestruction.new()]:
		observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
		_world.add_observer(observer)
	var contents: C_PackageContents = _parcel.get_component(C_PackageContents) as C_PackageContents
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_false(contents.released)
	assert_true(WorldSnapshotService.capture(self, 1).is_empty())
	assert_true(CommandBufferBarrier.drain_pending(_world))
	assert_true(contents.released)
	assert_eq(_world.query.with_all([C_Package]).execute().size(), 0)
	assert_false(WorldSnapshotService.capture(self, 1).is_empty())
	assert_true(CommandBufferBarrier.drain_pending(_world))
	assert_eq(_flow.parcel_incidents.size(), 1)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_incident_codec_is_closed_and_transaction_guard_rejects_capture() -> void:
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	var encoded: Dictionary = SaveDataCodec.encode(_flow.parcel_incidents[0]) as Dictionary
	var restored: CustomerParcelIncident = SaveDataCodec.decode(encoded) as CustomerParcelIncident
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.sequence, _flow.parcel_incidents[0].sequence)
	_flow.parcel_reaction_in_progress = true
	assert_true(WorldSnapshotService.capture(self, 1).is_empty())
	_flow.parcel_reaction_in_progress = false
#endregion


#region Committed intimidation and safe return
func test_native_demand_action_is_authored_once_and_only_available_for_actual_theft() -> void:
	_native_receiver(&"archetype/brute")
	var actions: C_InteractionActionSet = (
		_customer.get_component(C_InteractionActionSet) as C_InteractionActionSet
	)
	assert_eq(actions.actions.count(DEMAND_ACTION), 1)
	assert_eq(DEMAND_ACTION.slot, DEF_InteractionAction.Slot.INTERACT)
	assert_gt(DEMAND_ACTION.priority, 5)
	assert_false(DEMAND_ACTION.is_available(_actor, _customer, _customer))
	_decision(REACTIONS.Outcome.KEEP)
	assert_true(CustomerParcelIncidentService.react(_wrong_offer(), true))
	assert_true(DEMAND_ACTION.is_available(_actor, _customer, _customer))
	assert_eq(DEMAND_ACTION.caption_for(_actor, _customer, _customer), DEMAND_ACTION.caption)


func test_demand_attack_commits_one_memory_and_normal_combat_target_without_reroll() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.ATTACK)
	var elapsed: float = _agent.elapsed
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.ATTACK)
	assert_eq(incident.demand_strength, 5.0)
	assert_eq(incident.demand_tick, _cycle.clock.elapsed_ticks)
	assert_same(CombatQueries.target_for(_customer), _actor)
	assert_same(GrabQueries.held_object(_customer), _parcel)
	var person: NpcRecord = NpcPopulationQueries.person_for(_visit.customer_id)
	var memories: int = person.memories.size()
	assert_eq(memories, 1)
	var roll: float = incident.demand_roll
	incident = SaveDataCodec.decode(SaveDataCodec.encode(incident)) as CustomerParcelIncident
	_flow.parcel_incidents[0] = incident
	CombatService.end_combat(_customer)
	(_actor.get_component(C_Strength) as C_Strength).value = 100.0
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(person.memories.size(), memories)
	assert_null(CombatQueries.target_for(_customer))
	assert_eq(incident.demand_roll, roll)
	assert_eq(incident.demand_strength, 5.0)
	assert_eq(_agent.elapsed, elapsed)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_demand_return_transfers_one_actual_grip_and_starts_the_pair_block() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(200.0)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_null(GrabQueries.held_object(_customer))
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_eq(incident.next_eligible_tick, _cycle.clock.elapsed_ticks + (
		CustomerParcelIncidentService.BLOCK_TICKS
	))
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_null(CustomerHandoffService.select_offer(_actor, _customer, _visit))
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_busy_hands_without_support_keep_pending_return_and_allow_claim_without_reroll() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var other: Entity = SECOND_PARCEL.instantiate() as Entity
	EntityCompositionFixture.register(_world, other)
	other.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	assert_same(GrabQueries.held_object(_actor), other)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_customer), _parcel)
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.HELD)
	var roll: float = incident.demand_roll
	incident = SaveDataCodec.decode(SaveDataCodec.encode(incident)) as CustomerParcelIncident
	_flow.parcel_incidents[0] = incident
	assert_eq(DEMAND_ACTION.caption_for(_actor, _customer, _customer), "Забрать посылку")
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	(_actor.get_component(C_Strength) as C_Strength).value = 1.0
	GrabReleaseService.release(_actor, other)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_eq(incident.demand_strength, 5.0)
	assert_eq(incident.demand_roll, roll)


func test_busy_carry_returns_to_supported_clear_ground_without_replacing_the_occupant() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var other: Entity = SECOND_PARCEL.instantiate() as Entity
	EntityCompositionFixture.register(_world, other)
	(other as Node as Node3D).position = Vector3(5.0, 1.0, 0.0)
	other.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	_obstacle(Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 20.0))
	await get_tree().physics_frame
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_same(GrabQueries.held_object(_actor), other)
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert_true(solver.prepare(body))
	assert_gt(solver.bounds_at(body.global_transform).position.y, 0.0)
	assert_eq(body.linear_velocity, Vector3.ZERO)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)


func test_carry_interact_routes_actual_demand_instead_of_dropping_the_occupant() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var other: Entity = SECOND_PARCEL.instantiate() as Entity
	EntityCompositionFixture.register(_world, other)
	(other as Node as Node3D).global_position = _actor.hold_anchor.global_position - (
		_actor.hold_anchor.global_basis.z * 1.25
	)
	other.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	_obstacle(Vector3(0.0, -0.1, 0.0), Vector3(20.0, 0.2, 20.0))
	var interactor: C_Interactor = C_Interactor.new()
	_actor.add_component(interactor)
	var ray: RayCast3D = RayCast3D.new()
	_actor.add_child(ray)
	_actor.interaction_ray_cast = ray
	ray.global_position = (_actor as Node as Node3D).global_position + Vector3.UP * 1.5
	ray.look_at((_customer as Node as Node3D).global_position + Vector3.UP * 1.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	interactor.target = InteractionTargetingGeometry.find_target(_actor, interactor)
	assert_same(interactor.target, _customer, "Real ray reaches the NPC above the stolen parcel")
	assert_same(GrabQueries.held_in_slot(_actor, C_Grabbable.HoldSlot.CARRY), other)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.CARRY)
	assert_true(DEMAND_ACTION.is_available(_actor, _customer, _customer))
	var modal_token: int = InteractionControlFocus.acquire(
		_actor,
		self,
		InteractionControlFocus.Priority.MODAL,
	)
	assert_null(InteractionActionResolver.resolve(_actor, DEF_InteractionAction.Slot.INTERACT))
	InteractionActionResolver.execute_slot(_actor, DEF_InteractionAction.Slot.INTERACT, true)
	assert_eq(incident.demand_outcome, DEMAND.NONE)
	assert_same(GrabQueries.held_in_slot(_actor, C_Grabbable.HoldSlot.CARRY), other)
	InteractionControlFocus.release(_actor, modal_token)
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(
		_actor,
		DEF_InteractionAction.Slot.INTERACT,
	)
	assert_not_null(choice)
	if choice == null:
		return
	assert_same(choice.action, DEMAND_ACTION, "Carry must expose the accepted native demand")
	if choice.action != DEMAND_ACTION:
		return
	InteractionActionResolver.execute_slot(_actor, DEF_InteractionAction.Slot.INTERACT, true)
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_same(GrabQueries.held_in_slot(_actor, C_Grabbable.HoldSlot.CARRY), other)
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(DEMAND_ACTION.is_available(_actor, _customer, _customer))
	var fallback: InteractionActionChoice = InteractionActionResolver.resolve(
		_actor,
		DEF_InteractionAction.Slot.INTERACT,
	)
	assert_not_null(fallback)
	if fallback == null:
		return
	assert_true(fallback.action is DEF_GrabAction)
	if fallback.action is DEF_GrabAction:
		assert_eq((fallback.action as DEF_GrabAction).kind, DEF_GrabAction.Kind.RELEASE)


func test_player_own_carry_does_not_occlude_native_pending_return_action() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var other: Entity = SECOND_PARCEL.instantiate() as Entity
	EntityCompositionFixture.register(_world, other)
	other.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	var origin: Vector3 = GrabQueries.hold_anchor(_actor).global_position
	var surface: Vector3 = CustomerHandoffGeometry.closest_point(
		GrabQueries.physical_body(_parcel), origin,
	)
	var held_body: RigidBody3D = other as Node as RigidBody3D
	var collision: CollisionShape3D = other.get_node("CollisionShape3D") as CollisionShape3D
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.2
	collision.shape = shape
	collision.transform = Transform3D.IDENTITY
	held_body.global_position = origin.lerp(surface, 0.5)
	held_body.freeze = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, surface, CustomerParcelDemandGeometry.PLACEMENT.obstacle_mask,
		[_actor.get_rid(), (_customer as Node as PhysicsBody3D).get_rid(),
			GrabQueries.physical_body(_parcel).get_rid()],
	)
	var hit: Dictionary = held_body.get_world_3d().direct_space_state.intersect_ray(ray)
	assert_same(hit.get("collider"), held_body, "Native blocker fixture must hit own Carry")
	assert_same(GrabQueries.held_object(_actor), other)
	assert_true(DEMAND_ACTION.is_available(_actor, _customer, _customer))
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.HELD)
	assert_same(GrabQueries.held_object(_actor), other)
	assert_same(GrabQueries.held_object(_customer), _parcel)


func test_demand_rechecks_distance_and_los_without_committing_a_choice() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var original: Vector3 = (_actor as Node as Node3D).position
	(_actor as Node as Node3D).position.x += 10.0
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.NONE)
	(_actor as Node as Node3D).position = original
	var wall: StaticBody3D = _obstacle(Vector3(0.0, 1.0, -1.0), Vector3(4.0, 3.0, 0.1))
	await get_tree().physics_frame
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.NONE)
	wall.position.x += 10.0
	await get_tree().physics_frame
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))


func test_return_release_callback_cannot_capture_half_transfer_or_reroll_the_incident() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
		assert_eq(incident.demand_outcome, DEMAND.RETURN)
	_world.add_observer(observer)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(observer.snapshots.size(), 1)
	if not observer.snapshots.is_empty():
		assert_true(observer.snapshots[0].is_empty())
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_false(_flow.parcel_reaction_in_progress)
	_world.remove_observer(observer)


func test_return_release_callback_preserves_a_replacement_owner() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		_parcel.add_relationship(Relationship.new(R_HeldBy.new(), _customer))
	_world.add_observer(observer)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_customer), _parcel)
	assert_null(GrabQueries.held_object(_actor))
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.HELD)
	var roll: float = incident.demand_roll
	_world.remove_observer(observer)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_eq(incident.demand_roll, roll)
	assert_eq(incident.demand_strength, 5.0)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)


func test_return_callback_replacement_player_grip_keeps_the_incident_completed() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		_parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	_world.add_observer(observer)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	_world.remove_observer(observer)


func test_demand_window_uses_native_patience_and_departure_without_resetting_the_clock() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	_agent.elapsed = _visit.definition.patience_seconds
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.NONE)
	_agent.phase = C_CustomerAgent.Phase.LEAVING
	_agent.elapsed = 0.0
	assert_true(DEMAND_ACTION.is_available(_actor, _customer, _customer))
	_agent.elapsed = maxf(DEF_Customer.MINIMUM_LEAVING_SECONDS, _visit.definition.leaving_seconds)
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_eq(incident.demand_outcome, DEMAND.NONE)
	assert_eq(_agent.elapsed, _visit.definition.leaving_seconds)
	_agent.elapsed = 0.0
	_visit.finished = true
	assert_false(DEMAND_ACTION.complete(_actor, _customer, _customer))


func test_return_callback_filling_carry_without_floor_preserves_pending_npc_grip() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var other: Entity = SECOND_PARCEL.instantiate() as Entity
	EntityCompositionFixture.register(_world, other)
	(other as Node as Node3D).position = Vector3(5.0, 1.0, 0.0)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		other.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	_world.add_observer(observer)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_actor), other)
	assert_same(GrabQueries.held_object(_customer), _parcel)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.HELD)
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	_world.remove_observer(observer)
	GrabReleaseService.release(_actor, other)
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_same(GrabQueries.held_object(_actor), _parcel)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)


func test_return_callback_moving_player_away_cannot_acquire_the_stale_player_grip() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var observer: CaptureDuringRelease = CaptureDuringRelease.new()
	observer.capture_root = self
	observer.on_release = func() -> void:
		(_actor as Node as Node3D).position.x += 10.0
	_world.add_observer(observer)
	var pose: Transform3D = (_parcel as Node as Node3D).global_transform
	assert_true(DEMAND_ACTION.complete(_actor, _customer, _customer))
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_eq((_parcel as Node as Node3D).global_transform, pose)
	assert_true(EntityAvailability.contains(_parcel, _world))
	assert_eq(incident.demand_outcome, DEMAND.RETURN)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	_world.remove_observer(observer)
#endregion


#region Rightful order and physical destruction integration
func test_returned_stolen_parcel_delivers_and_pays_only_its_rightful_order_once() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var rightful: CustomerVisit = _rightful_order()
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(rightful.package_id)
	var history_id: String = record.history_id
	var number: int = record.number
	assert_true(CustomerParcelDemandService.demand(_actor, _customer as E_DistrictNpc))
	assert_eq(GrabQueries.held_object(_actor), _parcel)
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_false(rightful.settlement_committed)

	# A different real recipient receives the recovered box through the ordinary auto-handoff.
	var recipient: E_NpcCharacter = (
		load("res://content/domains/customers/entities/customer.tscn") as PackedScene
	).instantiate() as E_NpcCharacter
	(recipient as Node as RigidBody3D).freeze = true
	(recipient as Node as Node3D).position = Vector3(5.0, 0.0, -1.0)
	rightful.started = true
	EntityCompositionFixture.register_visit(_world, recipient, rightful)
	var agent: C_CustomerAgent = recipient.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	CustomerParcelAssignment.bind_parcel(recipient, rightful)
	(_actor as Node as Node3D).position = Vector3(5.0, 0.0, -2.0)
	_parcel.global_position = recipient.hold_anchor.global_position - Vector3(0.0, 0.0, 0.35)
	assert_true(CustomerFlowService.try_automatic_handoff(recipient, rightful))
	assert_eq(rightful.actual, CustomerVisit.Actual.DELIVERED)
	assert_null(GrabQueries.held_object(_actor))
	assert_true(CustomerFlowService.declare(rightful.visit_id, CustomerVisit.Declaration.TAKEN))
	assert_true(CustomerFlowService.declare(rightful.visit_id, CustomerVisit.Declaration.TAKEN))
	assert_false(CustomerFlowService.try_automatic_handoff(recipient, rightful))
	var wallet: C_Wallet = WalletService.current()
	assert_eq(wallet.balance, 100)
	assert_eq(wallet.operations.size(), 1)
	assert_eq(wallet.operations[0].reason, MoneyOperation.Reason.PAYMENT)
	assert_eq(record.history_id, history_id)
	assert_eq(record.number, number)
	assert_eq(rightful.package_history_id, history_id)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)
	assert_false(_visit.settlement_committed)


func test_destroyed_stolen_parcel_keeps_history_and_manual_loss_settles_complaint_once() -> void:
	var incident: CustomerParcelIncident = _stolen_for_demand(DEMAND.RETURN)
	var rightful: CustomerVisit = _rightful_order()
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(rightful.package_id)
	var history_id: String = record.history_id
	var number: int = record.number
	var capture: CaptureDestruction = CaptureDestruction.new()
	_world.add_observer(capture)
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_PackageDamage.new())
	_world.add_observer(O_PackageDestruction.new())
	var request: DamageRequest = DamageRequest.new()
	request.target = _parcel
	request.source = _customer
	request.instigator = _customer
	request.amount = (_parcel.get_component(C_Health) as C_Health).current
	_cycle.clock.elapsed_ticks += GameTimeRules.duration_ticks(3.0)
	assert_true(DamageRequestService.submit(request))
	assert_eq(capture.package_ids, [rightful.package_id])
	assert_eq(capture.actor_ids, [_customer.id])
	assert_eq(capture.held, [false])
	assert_eq(incident.phase, CustomerParcelIncident.Phase.COMPLETED)
	assert_eq(incident.next_eligible_tick, _cycle.clock.elapsed_ticks + (
		CustomerParcelIncidentService.BLOCK_TICKS
	))
	assert_null(GrabQueries.held_object(_customer))
	assert_null(PackageQueries.find_live_package(rightful.package_id))
	assert_eq(record.history_id, history_id)
	assert_eq(record.number, number)
	assert_true(record.active)
	assert_eq(rightful.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(rightful.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(rightful.loss_cause, CustomerVisit.LossCause.NONE)
	assert_false(rightful.finished)
	assert_true(WalletService.current().operations.is_empty())

	# The terminal's existing declaration closes an unstarted order; destruction itself did not.
	assert_true(CustomerFlowService.declare(rightful.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(rightful.finished)
	assert_true(rightful.settlement_committed)
	assert_eq(rightful.loss_cause, CustomerVisit.LossCause.DECLARED_LOST)
	assert_true(CustomerVisitLifecycle.create_complaint(rightful, _cycle.day_index))
	var complaint: CustomerComplaint = rightful.complaint
	CustomerOutcomeService.resolve_complaint(
		rightful, WalletService.current(), complaint.resolve_day,
	)
	assert_eq(complaint.outcome, CustomerComplaint.Outcome.ALREADY_SETTLED)
	assert_true(CustomerFlowService.declare(rightful.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(CustomerVisitLifecycle.create_complaint(rightful, _cycle.day_index))
	CustomerOutcomeService.resolve_complaint(
		rightful, WalletService.current(), complaint.resolve_day + 1,
	)
	assert_eq(complaint.resolved_day, complaint.resolve_day)
	var wallet: C_Wallet = WalletService.current()
	assert_eq(wallet.balance, -120)
	assert_eq(wallet.operations.size(), 1)
	assert_eq(wallet.operations[0].reason, MoneyOperation.Reason.LOST)
	assert_eq(rightful.complaint, complaint)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(_visit.settlement_committed)
	assert_eq(PackageHistoryService.record_for(rightful.package_id), record)
	_world.remove_observer(capture)
#endregion
