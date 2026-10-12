extends GutTest
## Real fire handoff, physical contents, durable ignition and common damage.

const FIRE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_fire_elemental.tres"
)
const DISTRICT: DEF_District = preload(
	"res://content/domains/npc/definitions/def_district_default.tres"
)
const FLASK: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_fire_flask.tres"
)
const TOY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
const BODY: PackedScene = preload("res://content/domains/npc/entities/district_npc.tscn")
const PARCEL: PackedScene = preload("res://content/domains/packages/entities/test_bread.tscn")
const BOOTH: PackedScene = preload("res://content/domains/customers/entities/inspection_booth.tscn")
const POLICY: DEF_Customer = preload(
	"res://content/domains/customers/definitions/def_customer_visit_default.tres"
)

var _root: Node3D
var _world: World
var _actor: E_DistrictNpc
var _person: NpcRecord
var _rule: DEF_NpcFireAura
var _visit: CustomerVisit
var _agent: C_CustomerAgent
var _parcel: E_Package


class BlastRecorder extends Observer:
	## Number of actual fire opening spawns; optionally retires its receiver at publication.
	var calls: int = 0
	## Tests the real synchronous factory boundary after the durable roll was committed.
	var retire_receiver: bool = false


	func query() -> QueryBuilder:
		return q.with_all([C_Hazard]).on_event(HazardSpawnResult.EVENT)


	func each(_event: Variant, entity: Entity, _payload: Variant = null) -> void:
		var hazard: C_Hazard = entity.get_component(C_Hazard) as C_Hazard
		if hazard.definition.key != &"npc_opening_fire_blast":
			return
		calls += 1
		if retire_receiver:
			var receiver: Entity = hazard.origin
			_world.remove_entity(receiver)
			receiver.free()


#region Native district and customer fixture
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	var floor: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30.0, 0.2, 30.0)
	collider.shape = shape
	collider.position.y = -0.1
	floor.add_child(collider)
	_root.add_child(floor)
	var session: Entity = Entity.new()
	var district: C_District = C_District.new()
	district.definition = DISTRICT
	session.component_resources = [
		district,
		C_DayCycle.new(),
		C_CustomerFlow.new(),
		C_PackageLedger.new(),
		C_LootDrops.new(),
	]
	_world.add_entity(session)
	_person = NpcRecord.new()
	_person.npc_id = &"fire/opening"
	_person.profile = FIRE.duplicate() as DEF_NpcArchetype
	_rule = FIRE.rule_for(DEF_NpcTrait.Kind.FIRE_AURA).duplicate() as DEF_NpcFireAura
	_rule.immediate_unpack_probability = 1.0
	_rule.opening_explosion_probability = 1.0
	_person.profile.rules = [_rule]
	_person.profile.optional_traits = []
	_person.variation = NpcVariationRules.create(_person.profile, 1234, _person.npc_id, 1)
	_person.placement = NpcRecord.Placement.STREET
	_person.phase_complete = true
	district.people.append(_person)
	_actor = BODY.instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		_actor,
		_world,
		String(_person.npc_id),
	)
	NpcConstructionService.configure_context(context, _person, DISTRICT)
	assert_true(EntityCompositionService.try_register(context))
	CustomerNpcLifecycleBinding.bind(_actor, _world)
	_actor.freeze = true
	_actor.place_at(Vector3.ZERO)
	_visit = CustomerVisit.new()
	_visit.visit_id = &"fire/visit"
	_visit.package_id = "fire/parcel"
	_visit.definition = POLICY
	_visit.started = true
	_visit.visit_count = 1
	CustomerFlowQueries.current().visits.append(_visit)
	_agent = C_CustomerAgent.new()
	_agent.visit_id = _visit.visit_id
	_agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_actor.add_component(_agent)
	_parcel = PARCEL.instantiate() as E_Package
	_parcel.package_definition = _parcel.package_definition.duplicate(true) as DEF_Package
	_parcel.package_definition.content_quantity = 1
	_parcel.gravity_scale = 0.0
	EntityCompositionFixture.register(_world, _parcel)
	(_parcel.get_component(C_Package) as C_Package).package_id = _visit.package_id
	(_parcel.get_component(C_PackageState) as C_PackageState).registration = (
		C_PackageState.Registration.REGISTERED
	)
	(_parcel.get_component(C_PackageContents) as C_PackageContents).selected_item = FLASK
	CustomerParcelAssignment.bind_parcel(_actor, _visit)
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	_world.add_observer(O_PackageOpening.new())
	_world.add_observer(O_PackageContents.new())
	_world.add_observer(O_CustomerInspectionCargo.new())
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ExplosionSetup.new())
	_world.add_observer(O_Damage.new())
	_world.add_system(S_Explosion.new())
	await _sync_physics()


func after_each() -> void:
	_world.purge(false)
	ECS.world = null
	_root.free()


func _handoff() -> void:
	assert_eq(
		(CustomerFlowService as Script).call("_resolve_delivery", _actor, _visit, _parcel, null),
		PackageDeliveryCheck.Result.READY,
	)


func _items() -> Array[Entity]:
	return _world.query.with_all([C_InventoryItem]).execute()


func _blast() -> Entity:
	return _world.query.with_all([C_Hazard, C_Explosion]).execute_one()


func _replay(item: Entity, actor_id: String = "") -> void:
	_world.emit_event(
		PackageContentPlaced.EVENT,
		_parcel,
		PackageContentPlaced.new(item, _parcel, _actor.id if actor_id.is_empty() else actor_id),
	)


func _restore_visit() -> void:
	_visit = SaveDataCodec.decode(SaveDataCodec.encode(_visit)) as CustomerVisit
	assert_not_null(_visit)
	CustomerFlowQueries.current().visits[0] = _visit


func _sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
#endregion


#region Immediate physical opening and committed outcomes
func test_native_service_branch_opens_fire_cargo_and_commits_only_one_blast() -> void:
	_rule.immediate_unpack_probability = 0.0
	_visit.definition = POLICY.duplicate() as DEF_Customer
	_visit.definition.private_inspection = true
	_visit.definition.inspection_unpack_probability = 1.0
	var booth: Entity = BOOTH.instantiate() as Entity
	(booth as Node as Node3D).position = Vector3(4.0, 0.0, 0.0)
	_world.add_entity(booth)
	var recorder: BlastRecorder = BlastRecorder.new()
	_world.add_observer(recorder)
	assert_true(CustomerInspectionService.begin(_actor, _visit, _parcel))
	assert_eq(_agent.phase, C_CustomerAgent.Phase.GOING_TO_BOOTH)
	CustomerInspectionService.arrive(_actor)
	NpcBrainService.bind_engine(_actor)
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	for update: int in range(2):
		decision.intent_owner = C_NpcDecision.Owner.NONE
		assert_true(NpcBrainService.update_tree(_actor, 0.1))
	assert_eq(_items().size(), 1)
	assert_eq(recorder.calls, 1)
	assert_true(_visit.fire_opening_decided)
	assert_true(_visit.fire_opening_explosion)


func test_authored_heat_rejects_invalid_probabilities_and_nonfire_blast() -> void:
	var rule: DEF_NpcFireAura = FIRE.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) as DEF_NpcFireAura
	assert_true(rule.valid_configuration())
	assert_eq(rule.immediate_unpack_probability, 0.8)
	assert_eq(rule.opening_explosion_probability, 0.3)
	assert_eq(rule.opening_explosion.damage_type, DamageRequest.Type.FIRE)
	assert_eq(rule.ignition_items.size(), 2)
	assert_true(FLASK in rule.ignition_items)
	for invalid: float in [-0.1, 1.1, INF, NAN]:
		_rule.immediate_unpack_probability = invalid
		assert_false(_rule.valid_configuration())
	_rule.immediate_unpack_probability = 1.0
	_rule.opening_explosion_probability = NAN
	assert_false(_rule.valid_configuration())
	_rule.opening_explosion_probability = 1.0
	_rule.opening_explosion = _rule.opening_explosion.duplicate() as DEF_Explosion
	_rule.opening_explosion.damage_type = DamageRequest.Type.IMPACT
	assert_false(_rule.valid_configuration())


func test_real_handoff_opens_immediately_in_owned_slot_without_booth() -> void:
	_handoff()
	assert_eq(_agent.phase, C_CustomerAgent.Phase.INSPECTING)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(CustomerInspectionQueries.owner_for(_parcel), _actor)
	assert_true((PhysicalSlotService.relationship(_parcel).relation as R_StoredIn).applied)
	assert_eq(
		(_parcel.get_component(C_PackageState) as C_PackageState).opening,
		C_PackageState.Opening.OPENED,
	)
	assert_eq(_items().size(), 1)
	assert_same(CustomerInspectionQueries.owner_for(_items()[0]), _actor)
	assert_true(_visit.fire_opening_decided)
	assert_true(_visit.fire_opening_explosion)
	assert_not_null(_blast())
	assert_eq((_blast().get_component(C_Hazard) as C_Hazard).instigator_id, _actor.id)
	assert_eq((_blast().get_component(C_Hazard) as C_Hazard).definition, _rule.opening_explosion)


func test_zero_immediate_probability_keeps_ordinary_delivery_without_opening_or_ignition() -> void:
	_rule.immediate_unpack_probability = 0.0
	_handoff()
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_false(_visit.package_opened)
	assert_false(_visit.fire_opening_decided)
	assert_null(_blast())
	assert_true(_items().is_empty())


func test_unrelated_real_toy_content_never_rolls_or_explodes() -> void:
	(_parcel.get_component(C_PackageContents) as C_PackageContents).selected_item = TOY
	_handoff()
	assert_eq(_items().size(), 1)
	assert_eq((_items()[0].get_component(C_InventoryItem) as C_InventoryItem).definition, TOY)
	assert_false(_visit.fire_opening_decided)
	assert_null(_blast())


func test_false_roll_survives_replay_changed_tuning_and_native_record_codec() -> void:
	_rule.opening_explosion_probability = 0.0
	_handoff()
	assert_true(_visit.fire_opening_decided)
	assert_false(_visit.fire_opening_explosion)
	assert_null(_blast())
	_restore_visit()
	_rule.opening_explosion_probability = 1.0
	_replay(_items()[0])
	assert_true(_visit.fire_opening_decided)
	assert_false(_visit.fire_opening_explosion)
	assert_null(_blast())


func test_multiple_real_reagents_and_replay_submit_only_one_durable_blast() -> void:
	var recorder: BlastRecorder = BlastRecorder.new()
	_world.add_observer(recorder)
	_parcel.package_definition.content_quantity = 2
	_handoff()
	assert_eq(_items().size(), 2)
	assert_eq(recorder.calls, 1)
	_restore_visit()
	for item: Entity in _items():
		_replay(item)
	assert_eq(recorder.calls, 1)
	assert_true(_visit.fire_opening_explosion)


func test_foreign_opening_fact_cannot_ignite_the_current_receiver_cargo() -> void:
	_rule.immediate_unpack_probability = 0.0
	_visit.definition = POLICY.duplicate() as DEF_Customer
	_visit.definition.private_inspection = true
	var booth: Entity = BOOTH.instantiate() as Entity
	_world.add_entity(booth)
	assert_true(CustomerInspectionService.begin(_actor, _visit, _parcel))
	var item: Entity = (load(FLASK.world_pickup_scene) as PackedScene).instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	var state: C_PackageState = _parcel.get_component(C_PackageState) as C_PackageState
	state.opening = C_PackageState.Opening.OPENED
	(_parcel.get_component(C_PackageContents) as C_PackageContents).released = true
	_replay(item, "different/opener")
	assert_false(_visit.fire_opening_decided)
	assert_null(_blast())
	_replay(item)
	assert_true(_visit.fire_opening_decided)
	assert_not_null(_blast())


func test_common_blast_damages_near_receiver_once_and_fire_source_is_immune() -> void:
	_handoff()
	var victim: E_NpcCharacter = (
		load("res://content/domains/customers/entities/customer.tscn") as PackedScene
	).instantiate() as E_NpcCharacter
	EntityCompositionFixture.register(_world, victim)
	victim.freeze = true
	victim.global_position = (_blast() as Node as Node3D).global_position + Vector3(1.0, 0.0, 0.0)
	await _sync_physics()
	var health: C_Health = victim.get_component(C_Health) as C_Health
	_world.process(0.0)
	assert_lt(health.current, 100.0)
	assert_eq((_actor.get_component(C_Health) as C_Health).current, 100.0)
	var after: float = health.current
	_world.process(0.0)
	assert_eq(health.current, after)


func test_blast_receiver_retirement_preserves_opening_without_stale_reads() -> void:
	var recorder: BlastRecorder = BlastRecorder.new()
	recorder.retire_receiver = true
	_world.add_observer(recorder)
	var reference: WeakRef = weakref(_actor)
	_handoff()
	assert_eq(recorder.calls, 1)
	assert_null(reference.get_ref())
	assert_true(_visit.fire_opening_decided)
	assert_true(_visit.fire_opening_explosion)
	assert_eq(
		(_parcel.get_component(C_PackageState) as C_PackageState).opening,
		C_PackageState.Opening.OPENED,
	)
#endregion
