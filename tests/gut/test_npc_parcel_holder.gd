extends GutTest
## Native NPC capability participates in the actual grip lifecycle and physical carry solver.

const NPC: PackedScene = preload("res://content/domains/npc/entities/npc_character.tscn")
const PARCEL: PackedScene = preload("res://content/domains/packages/entities/package_a.tscn")

var _world: World
var _npc: E_NpcCharacter
var _parcel: E_Package


#region Real native fixture
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_npc = _holder(Vector3.ZERO)
	_parcel = PARCEL.instantiate() as E_Package
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	body.position = _npc.hold_anchor.global_position - Vector3.BACK * 0.35
	EntityCompositionFixture.register(_world, _parcel)


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _holder(position: Vector3) -> E_NpcCharacter:
	var actor: E_NpcCharacter = NPC.instantiate() as E_NpcCharacter
	var body: CharacterBody3D = actor as Node as CharacterBody3D
	body.position = position
	EntityCompositionFixture.register(_world, actor)
	body.set_physics_process(false)
	return actor


func _grip(holder: Entity) -> Relationship:
	var grip: Relationship = Relationship.new(R_HeldBy.new(), holder)
	_parcel.add_relationship(grip)
	return grip
#endregion


#region Authored capability and live ownership
func test_authored_carry_strength_rejects_nonpositive_and_nonfinite_values() -> void:
	var capability: ET_NpcParcelHolder = ET_NpcParcelHolder.new()
	for invalid: float in [0.0, -1.0, NAN, INF]:
		capability.carry_strength = invalid
		assert_false(capability.configuration_issues(null).is_empty())
	capability.carry_strength = 0.1
	assert_true(capability.configuration_issues(null).is_empty())
	var recipes: Array[Component] = capability.recipes_for(null)
	assert_eq((recipes[2] as C_Strength).base, 0.1)
	assert_eq((recipes[2] as C_Strength).value, 0.1)


func test_native_npc_has_isolated_carry_data_and_the_authored_physical_anchor() -> void:
	var other: E_NpcCharacter = _holder(Vector3(3, 0, 0))
	assert_true(_npc.has_component(C_GrabControl))
	assert_true(_npc.has_component(C_CarryLoad))
	assert_true(_npc.has_component(C_Strength))
	assert_not_same(_npc.get_component(C_GrabControl), other.get_component(C_GrabControl))
	assert_not_same(_npc.get_component(C_CarryLoad), other.get_component(C_CarryLoad))
	assert_not_same(_npc.get_component(C_Strength), other.get_component(C_Strength))
	assert_same(GrabQueries.hold_anchor(_npc), _npc.get_node("HandoffAnchor"))
	assert_almost_eq((_npc.get_component(C_Strength) as C_Strength).value, 6.0, 0.0001)
	assert_almost_eq(
		(_npc.get_component(C_GrabControl) as C_GrabControl).hold_distance,
		0.35,
		0.0001,
	)


func test_released_source_and_npc_grip_have_one_live_owner_and_one_physical_exception() -> void:
	var source: E_NpcCharacter = _holder(Vector3(3, 0, 0))
	_grip(source)
	assert_same(GrabQueries.held_object(source), _parcel)
	GrabReleaseService.release(source, _parcel)
	var grip: Relationship = _grip(_npc)
	assert_true((grip.relation as R_HeldBy).lifecycle_applied)
	assert_same(GrabQueries.held_object(_npc), _parcel)
	assert_null(GrabQueries.held_object(source))
	assert_true((_npc.get_component(C_CarryLoad) as C_CarryLoad).active)
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	assert_has(body.get_collision_exceptions(), _npc)
	assert_does_not_have(body.get_collision_exceptions(), source)
	var grip_count: int = 0
	for link: Relationship in _parcel.relationships:
		if link.relation is R_HeldBy:
			grip_count += 1
	assert_eq(grip_count, 1)


func test_district_factory_publishes_the_carry_contract_alongside_roster_identity() -> void:
	var district: DEF_District = load(
		"res://content/domains/npc/definitions/def_district_default.tres"
	)
	var person: NpcRecord = NpcPopulationRules.initial_records(district, 1, 0)[0]
	var actor: E_DistrictNpc = (
		load("res://content/domains/npc/entities/district_npc.tscn") as PackedScene
	).instantiate() as E_DistrictNpc
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		actor,
		_world,
		"holder/district",
	)
	NpcConstructionService.configure_context(context, person, district)
	var registered: bool = EntityCompositionService.try_register(context)
	assert_true(registered)
	if not registered:
		actor.free()
		return
	assert_eq((actor.get_component(C_NpcIdentity) as C_NpcIdentity).npc_id, person.npc_id)
	assert_true(actor.has_component(C_GrabControl))
	assert_true(actor.has_component(C_CarryLoad))
	assert_true(actor.has_component(C_Strength))
	var grip: Relationship = _grip(actor)
	assert_true((grip.relation as R_HeldBy).lifecycle_applied)
	assert_same(GrabQueries.held_object(actor), _parcel)


func test_standalone_customer_keeps_the_carry_contract_with_its_explicit_visit_trait() -> void:
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new()]
	_world.add_entity(session)
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"holder/customer"
	visit.definition = DEF_Customer.new()
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(visit)
	var actor: E_NpcCharacter = (
		load("res://content/domains/customers/entities/customer.tscn") as PackedScene
	).instantiate() as E_NpcCharacter
	actor.set_physics_process(false)
	EntityCompositionFixture.register_visit(_world, actor, visit)
	actor.set_physics_process(false)
	assert_true(actor.has_component(C_CustomerAgent))
	assert_true(actor.has_component(C_GrabControl))
	assert_true(actor.has_component(C_CarryLoad))
	assert_true(actor.has_component(C_Strength))
	var grip: Relationship = _grip(actor)
	assert_true((grip.relation as R_HeldBy).lifecycle_applied)
	assert_same(GrabQueries.held_object(actor), _parcel)


func test_native_parcel_solver_follows_the_npc_anchor_without_a_player_input_controller() -> void:
	var grip: Relationship = _grip(_npc)
	assert_true((grip.relation as R_HeldBy).lifecycle_applied)
	assert_false(_npc.has_component(C_PlayerInputController))
	for frame: int in 30:
		await get_tree().physics_frame
	var actor_body: Node3D = _npc as Node as Node3D
	actor_body.position.x += 0.3
	var target: Vector3 = (
		_npc.hold_anchor.global_position
		- _npc.hold_anchor.global_basis.z * (grip.relation as R_HeldBy).hold_distance
	)
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	var initial_error: float = body.global_position.distance_to(target)
	for frame: int in 45:
		await get_tree().physics_frame
	assert_same(GrabQueries.held_object(_npc), _parcel)
	assert_lt(body.global_position.distance_to(target), initial_error * 0.5)
	assert_true(body.global_position.is_finite())


func test_disabling_the_holder_releases_the_real_grip_load_and_collision_exception() -> void:
	_grip(_npc)
	assert_same(GrabQueries.held_object(_npc), _parcel)
	_world.disable_entity(_npc)
	assert_null(GrabQueries.held_relationship(_parcel))
	assert_null(GrabQueries.held_object(_npc))
	assert_false((_npc.get_component(C_CarryLoad) as C_CarryLoad).active)
	assert_does_not_have((_parcel as Node as RigidBody3D).get_collision_exceptions(), _npc)
	assert_true(EntityAvailability.contains(_parcel, _world))
#endregion
