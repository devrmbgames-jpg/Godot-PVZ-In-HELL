extends GutTest
## Ближний автоприём через обычный CustomerFlow с физическими участниками.

var _world: World
var _actor: E_RigidBodyCharacter
var _customer: E_Customer
var _agent: C_CustomerAgent
var _cycle: C_DayCycle
var _visit: CustomerVisit
var _parcel: E_Package


func before_each() -> void:
	if bool(Console.is_visible()): Console.toggle_console()
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
	_actor.component_resources = [C_PlayerInputController.new(), C_Controller.new(), C_GrabControl.new(), C_CarryLoad.new(), C_Strength.new(), C_Motion.new(), C_Health.new()]
	_world.add_entity(_actor)
	(_actor.get_component(C_Health) as C_Health).current = 10.0
	_customer = (load("res://content/entities/customers/customer.tscn") as PackedScene).instantiate() as E_Customer
	(_customer as Node as RigidBody3D).freeze = true
	(_customer as Node as Node3D).position = Vector3(0, 0, -1)
	_world.add_entity(_customer)
	_agent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	_agent.visit_id = _visit.visit_id
	_agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_parcel = (load("res://content/entities/packages/package_a.tscn") as PackedScene).instantiate() as E_Package
	(_parcel as Node as RigidBody3D).gravity_scale = 0.0
	_world.add_entity(_parcel)
	(_parcel.get_component(C_Package) as C_Package).package_id = _visit.package_id
	(_parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState.Registration.REGISTERED
	CustomerFlowService.bind_parcel(_customer, _visit)
	_parcel.add_relationship(Relationship.new(R_HeldBy.new(), _actor))


func after_each() -> void:
	if bool(Console.is_visible()): Console.toggle_console()
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _expect_held() -> void:
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(GrabService.held_object(_actor), _parcel)


func test_waiting_customer_takes_correct_carry_once_without_button_or_greeting_delay() -> void:
	_agent.phase = C_CustomerAgent.Phase.WAITING
	await get_tree().physics_frame
	CustomerFlowService._step(_customer, _cycle, 0.0)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.RECEIVING)
	assert_null(GrabService.held_object(_actor))
	assert_false(EntityAvailability.contains(_parcel, _world))
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_false(_agent.dialogue_started)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE, "Actual delivery does not replace terminal accounting")


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
		if binding.relation is R_AssignedTo: _parcel.remove_relationship(binding)
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	assert_eq(message.text, original_text, "Automatic retries must not spam rejection bubbles")


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


func test_busy_controls_dialogue_departure_and_defeated_participants_reject() -> void:
	await get_tree().physics_frame
	for priority: InteractionControlFocus.Priority in [InteractionControlFocus.Priority.PUSH, InteractionControlFocus.Priority.PROLONGED, InteractionControlFocus.Priority.MODAL]:
		var token: int = InteractionControlFocus.acquire(_actor, self, priority)
		assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
		_expect_held()
		InteractionControlFocus.release(_actor, token)
	Console.toggle_console()
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	Console.toggle_console()
	for phase: C_CustomerAgent.Phase in [C_CustomerAgent.Phase.DIALOGUE, C_CustomerAgent.Phase.LEAVING, C_CustomerAgent.Phase.AGGRESSIVE]:
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


func test_disabled_automatic_mode_keeps_manual_handoff_and_refusal_policy() -> void:
	_visit.definition.automatic_handoff = false
	_visit.definition.voluntary_refusal = true
	await get_tree().physics_frame
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	_expect_held()
	assert_eq(CustomerFlowService.confirm_direct_delivery(_actor, _customer), PackageDeliveryCheck.Result.READY)
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_null(GrabService.held_object(_actor))
	assert_true(EntityAvailability.contains(_parcel, _world))


func test_automatic_receive_borrows_to_booth_without_finishing_delivery() -> void:
	_visit.definition.private_inspection = true
	var booth: Entity = (load("res://content/entities/customers/inspection_booth.tscn") as PackedScene).instantiate() as Entity
	(booth as Node as Node3D).position.x = 4.0
	_world.add_entity(booth)
	await get_tree().physics_frame
	assert_true(CustomerFlowService.try_automatic_handoff(_customer, _visit))
	assert_eq(_agent.phase, C_CustomerAgent.Phase.GOING_TO_BOOTH)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_null(GrabService.held_object(_actor))
	assert_eq(CustomerInspectionService.owner_for(_parcel), _customer)
	assert_true((_parcel as Node as RigidBody3D).freeze)
	assert_false(CustomerFlowService.try_automatic_handoff(_customer, _visit))
