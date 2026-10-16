extends GutTest
## Ближний автоприём через обычный CustomerFlow с физическими участниками.

var _world: World
var _actor: E_RigidBodyCharacter
var _customer: E_NpcCharacter
var _agent: C_CustomerAgent
var _cycle: C_DayCycle
var _visit: CustomerVisit
var _parcel: E_Package


#region Физическое тестовое окружение
## Создаёт физического игрока, клиента и зарегистрированную коробку в его руках.
func before_each() -> void:
	if bool(Console.is_visible()):
		Console.toggle_console()
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_GrabLifecycle.new())
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new(), C_PackageLedger.new()]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_visit = CustomerVisit.new()
	_visit.visit_id = &"handoff"
	_visit.package_id = "handoff-parcel"
	_visit.definition = DEF_Customer.new()
	_visit.started = true
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)

	var body: RigidBody3D = RigidBody3D.new()
	body.set_script(E_RigidBodyCharacter)
	body.freeze = true
	_actor = body as Node as E_RigidBodyCharacter
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0, 1.3, -0.5)
	body.add_child(anchor)
	_actor.head_axis_x = anchor
	_actor.hold_anchor = anchor
	_actor.component_resources = ([
		C_PlayerInputController.new(),
		C_Controller.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_Motion.new(),
		C_Health.new(),
	])
	_world.add_entity(_actor)
	(_actor.get_component(C_Health) as C_Health).current = 10.0
	_customer = (
		(
			load("res://content/domains/customers/entities/customer.tscn") as PackedScene
		).instantiate()
		as E_NpcCharacter
	)
	(_customer as Node as RigidBody3D).freeze = true
	(_customer as Node as Node3D).position = Vector3(0, 0, -1)
	EntityCompositionFixture.register_visit(_world, _customer, _visit)
	_agent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	_agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_parcel = (
		(
			load("res://content/domains/packages/entities/package_a.tscn") as PackedScene
		).instantiate()
		as E_Package
	)
	(_parcel as Node as RigidBody3D).gravity_scale = 0.0
	EntityCompositionFixture.register(_world, _parcel)
	(_parcel.get_component(C_Package) as C_Package).package_id = _visit.package_id
	(_parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState \
			.Registration \
			.REGISTERED
	CustomerParcelAssignment.bind_parcel(_customer, _visit)
	_parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	(_parcel as Node as Node3D).global_position = _actor.hold_anchor.global_position


## Удаляет World и даёт отложенным удалениям завершиться перед следующим тестом.
func after_each() -> void:
	if bool(Console.is_visible()):
		Console.toggle_console()
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _expect_held() -> void:
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(GrabQueries.held_object(_actor), _parcel)


func _can_receive() -> bool:
	return CustomerHandoffService.can_receive(_actor, _customer, _visit, _parcel, true)


func _known_box(size: Vector3 = Vector3(0.4, 0.4, 0.4)) -> CollisionShape3D:
	var collision: CollisionShape3D = _parcel.get_node("CollisionShape3D") as CollisionShape3D
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.transform = Transform3D.IDENTITY
	return collision

#endregion


#region Exact grip-to-surface reach
func test_strict_one_metre_boundary_ignores_larger_legacy_distance() -> void:
	_known_box()
	var customer_body: Node3D = _customer as Node as Node3D
	customer_body.global_transform = Transform3D.IDENTITY
	_customer.hold_anchor.position = Vector3.ZERO
	assert_eq(_customer.hold_anchor.global_position, Vector3.ZERO)
	_visit.definition.automatic_handoff_distance = 3.0
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	for gap: float in [1.001, 1.0, 0.9999]:
		body.global_position = Vector3(0.0, 0.0, -gap - 0.2)
		assert_eq(_can_receive(), gap < 1.0, "Surface gap %.4f m" % gap)
		_expect_held()


func test_long_parcel_is_reachable_by_surface_even_with_distant_centres() -> void:
	_known_box(Vector3(0.4, 0.4, 2.0))
	var origin: Vector3 = _customer.hold_anchor.global_position
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	body.global_position = origin + Vector3(0.0, 0.2, -1.7)
	var actor_body: Node3D = _actor as Node as Node3D
	actor_body.global_position = body.global_position - _actor.hold_anchor.position
	var customer_body: Node3D = _customer as Node as Node3D
	assert_gt(actor_body.global_position.distance_to(customer_body.global_position), 1.0)
	assert_gt(origin.distance_to(body.global_position), 1.0)
	assert_true(_can_receive())
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


func test_rotated_scaled_offset_shape_uses_its_surface_instead_of_world_aabb() -> void:
	var collision: CollisionShape3D = _known_box()
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	body.global_transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(3.0, 1.0, -2.0))
	collision.transform = Transform3D(
		Basis(Vector3.UP, 0.4).scaled_local(Vector3(2.0, 1.0, 0.5)),
		Vector3(0.4, 0.2, 0.1),
	)
	var pose: Transform3D = collision.global_transform
	var origin: Vector3 = pose * Vector3(0.7, 0.5, 0.6)
	var expected: Vector3 = pose * Vector3(0.2, 0.2, 0.2)
	assert_almost_eq(
		CustomerHandoffGeometry.closest_point(body, origin), expected, Vector3.ONE * 0.0001,
	)


func test_native_packaging_families_have_supported_physical_surfaces() -> void:
	var names: Array[String] = [
		"package", "package_a", "package_b", "package_big", "package_barrel", "package_long",
	]
	for family_name: String in names:
		var source: RigidBody3D = (
			load("res://content/domains/packages/entities/" + family_name + ".tscn") as PackedScene
		).instantiate() as RigidBody3D
		var collision: CollisionShape3D = source.get_node("CollisionShape3D") as CollisionShape3D
		assert_true(collision.shape is BoxShape3D, family_name)
		var sample: RigidBody3D = RigidBody3D.new()
		sample.freeze = true
		sample.collision_layer = 0
		sample.transform = source.transform
		var actual: CollisionShape3D = collision.duplicate() as CollisionShape3D
		sample.add_child(actual)
		add_child_autofree(sample)
		var box: BoxShape3D = actual.shape as BoxShape3D
		var pose: Transform3D = actual.global_transform
		var expected: Vector3 = pose * Vector3(box.size.x * 0.5, 0.0, 0.0)
		var origin: Vector3 = expected + pose.basis.x.normalized() * 0.5
		assert_almost_eq(
			CustomerHandoffGeometry.closest_point(sample, origin), expected, Vector3.ONE * 0.0001,
		)
		source.free()


func test_missing_anchor_invalid_distance_and_unsupported_shape_never_use_centre_fallback() -> void:
	for distance: float in [NAN, INF, 0.0, -1.0]:
		_visit.definition.automatic_handoff_distance = distance
		assert_false(_can_receive())
	_visit.definition.automatic_handoff_distance = 1.0
	var anchor: Node3D = _customer.hold_anchor
	_customer.hold_anchor = null
	assert_false(_can_receive())
	_customer.hold_anchor = anchor
	var collision: CollisionShape3D = _parcel.get_node("CollisionShape3D") as CollisionShape3D
	collision.shape = SphereShape3D.new()
	assert_false(_can_receive())
	collision = _known_box()
	collision.disabled = true
	assert_false(_can_receive())
	_expect_held()


func test_grip_inside_parcel_still_rejects_an_intersecting_wall() -> void:
	_known_box()
	var origin: Vector3 = _customer.hold_anchor.global_position
	var body: RigidBody3D = _parcel as Node as RigidBody3D
	body.freeze = true
	body.global_position = origin
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.2
	collision.shape = shape
	wall.add_child(collision)
	wall.position = origin
	_world.add_child(wall)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(_can_receive(), "Overlapping geometry must not bypass the obstacle query")
	_expect_held()
	wall.position.x += 10.0
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(_can_receive())


func test_compatibility_query_rejects_missing_or_retired_participants_without_mutation() -> void:
	await get_tree().physics_frame
	assert_true(_can_receive())
	assert_false(CustomerHandoffService.can_receive(_actor, null, _visit, _parcel, true))
	assert_false(CustomerHandoffService.can_receive(null, _customer, _visit, _parcel, true))
	_world.remove_entity(_customer)
	assert_false(_can_receive())
	_expect_held()


func test_pause_or_changed_holder_rejects_before_delivery_mutation() -> void:
	get_tree().paused = true
	assert_false(_can_receive())
	get_tree().paused = false
	_expect_held()
	_parcel.remove_relationship(GrabQueries.held_relationship(_parcel))
	assert_false(_can_receive())
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
#endregion


#region Автоприём и ограничения
## Автоприём забирает правильную коробку один раз, не открывая диалог и не подменяя учёт.
func test_waiting_customer_takes_correct_carry_once_without_button_or_greeting_delay() -> void:
	_agent.phase = C_CustomerAgent.Phase.WAITING
	await get_tree().physics_frame
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.RECEIVING)
	assert_null(GrabQueries.held_object(_actor))
	assert_false(EntityAvailability.contains(_parcel, _world))
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_false(_agent.dialogue_started)
	assert_eq(
		_visit.declaration,
		CustomerVisit.Declaration.NONE,
		"Actual delivery does not replace terminal accounting",
	)


## Неподходящая коробка остаётся в руках; повторные попытки не засоряют реплики отказами.
func test_wrong_unregistered_destroyed_and_unassigned_orders_stay_held_silently() -> void:
	await get_tree().physics_frame
	var message: Label3D = _customer.get_node("Message") as Label3D
	var original_text: String = message.text
	var identity: C_Package = _parcel.get_component(C_Package) as C_Package
	identity.package_id = "someone-else"
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	identity.package_id = _visit.package_id

	var state: C_PackageState = _parcel.get_component(C_PackageState) as C_PackageState
	state.registration = C_PackageState.Registration.UNREGISTERED
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	state.registration = C_PackageState.Registration.REGISTERED
	state.damage = C_PackageState.Damage.DESTROYED
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	state.damage = C_PackageState.Damage.UNDAMAGED
	for binding: Relationship in _parcel.relationships.duplicate():
		if binding.relation is R_AssignedTo:
			_parcel.remove_relationship(binding)
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	assert_eq(message.text, original_text, "Automatic retries must not spam rejection bubbles")


## Авторская дистанция и физическая стена блокируют передачу до появления свободного пути.
func test_profile_distance_and_wall_reject_then_clear_path_allows_receive() -> void:
	await get_tree().physics_frame
	_visit.definition.automatic_handoff_distance = 0.5
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	_visit.definition.automatic_handoff_distance = 1.5
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2, 3, 0.1)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector3(0, 1.3, -0.75)
	_world.add_child(wall)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	wall.position.x = 10.0
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


## Занятый ввод, диалог, уход, агрессия и поражение участника блокируют автоприём.
func test_busy_controls_dialogue_departure_and_defeated_participants_reject() -> void:
	await get_tree().physics_frame
	for priority: InteractionControlFocus.Priority in ([
		InteractionControlFocus.Priority.PUSH,
		InteractionControlFocus.Priority.PROLONGED,
		InteractionControlFocus.Priority.MODAL,
	]):
		var token: int = InteractionControlFocus.acquire(_actor, self, priority)
		assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
		_expect_held()
		InteractionControlFocus.release(_actor, token)
	Console.toggle_console()
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	Console.toggle_console()
	for phase: C_CustomerAgent.Phase in ([
		C_CustomerAgent.Phase.DIALOGUE,
		C_CustomerAgent.Phase.LEAVING,
		C_CustomerAgent.Phase.AGGRESSIVE,
	]):
		_agent.phase = phase
		assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
		_expect_held()
	_agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	(_actor.get_component(C_Motion) as C_Motion).control_enabled = false
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	(_actor.get_component(C_Motion) as C_Motion).control_enabled = true
	(_customer.get_component(C_Health) as C_Health).current = 0.0
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	(_customer.get_component(C_Health) as C_Health).current = 10.0
	_actor.add_component(C_Death.new())
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()

#endregion


#region Ручной режим и осмотр
## Отключённый автоприём сохраняет ручную выдачу и авторскую политику отказа.
func test_disabled_automatic_mode_keeps_manual_handoff_and_refusal_policy() -> void:
	_visit.definition.automatic_handoff = false
	_visit.definition.voluntary_refusal = true
	await get_tree().physics_frame
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	assert_eq(
		CustomerFlowService.confirm_direct_delivery(_actor, _customer),
		PackageDeliveryCheck.Result.READY,
	)
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_null(GrabQueries.held_object(_actor))
	assert_true(EntityAvailability.contains(_parcel, _world))


## Осмотр временно забирает коробку в физический слот, сохраняя незавершённый исход.
func test_automatic_receive_borrows_to_booth_without_finishing_delivery() -> void:
	_visit.definition.private_inspection = true
	var booth: Entity = (
		(
			load("res://content/domains/customers/entities/inspection_booth.tscn") as PackedScene
		).instantiate()
		as Entity
	)
	(booth as Node as Node3D).position.x = 4.0
	_world.add_entity(booth)
	await get_tree().physics_frame
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(_agent.phase, C_CustomerAgent.Phase.GOING_TO_BOOTH)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_null(GrabQueries.held_object(_actor))
	assert_eq(CustomerInspectionQueries.owner_for(_parcel), _customer)
	assert_true((_parcel as Node as RigidBody3D).freeze)
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))

#endregion
