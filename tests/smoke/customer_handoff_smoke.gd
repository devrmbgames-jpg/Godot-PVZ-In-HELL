extends Node
## Сценарий прямой выдачи и отказа проверяет живое владение предметом после передачи клиенту.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 600
const PICKUP_OFFSET: Vector3 = Vector3(0, 0.5, -1)

var _level: Node = null
var _actor: Entity = null


#region Сценарий прямой передачи
func _ready() -> void:
	_run.call_deferred()


## Проверяет прямую выдачу и физический отказ в историческом сценарии восьми коробок.
func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	(_actor as Node).set_physics_process(false)
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	var books: Entity = PackageQueries.find_live_package("base_supply:1:books")
	var glass: Entity = PackageQueries.find_live_package("base_supply:1:glass")
	assert(books != null and glass != null)
	assert(PackageRegistrationService.register_package(books).outcome == PackageScanResult.Outcome.REGISTERED)
	assert(PackageRegistrationService.register_package(glass).outcome == PackageScanResult.Outcome.REGISTERED)
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = flow.schedule.duplicate(true) as DEF_CustomerSchedule
	for event: DEF_CustomerEvent in flow.schedule.events:
		event.customer.greeting_seconds = 0.05
		event.customer.receiving_seconds = 0.05
		event.customer.leaving_seconds = 0.05

	var cycle: C_DayCycle = DayPhaseQueries.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	var customer: E_NpcCharacter = await _waiting_customer()
	assert(CustomerFlowService.direct_handoff_package(_actor, customer) == null)
	await _pickup(glass)
	assert(CustomerFlowService.confirm_direct_delivery(_actor, customer) == PackageDeliveryCheck.Result.WRONG_PACKAGE)
	assert(GrabService.held_object(_actor) == glass, "Wrong package must stay held")
	GrabService.release(_actor, glass)
	await _pickup(books)

	var first: CustomerVisit = CustomerFlowQueries.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	var action: DEF_CustomerHandoffAction = DEF_CustomerHandoffAction.new()
	assert(action.is_available(_actor, customer, customer))
	action.execute(_actor, customer, customer)
	assert(first.actual == CustomerVisit.Actual.DELIVERED)
	assert(first.declaration == CustomerVisit.Declaration.NONE)
	assert(GrabService.held_object(_actor) == null, "Delivered package must release the grip")
	customer = await _waiting_customer()

	var second: CustomerVisit = CustomerFlowQueries.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)
	assert(second.package_id == "base_supply:1:glass")
	second.definition.voluntary_refusal = true
	assert(not CustomerFlowService.voluntary_refuse(customer), "Customer cannot refuse before physical handoff")
	assert(second.actual == CustomerVisit.Actual.NOT_RESOLVED)
	(glass.get_component(C_PackageState) as C_PackageState).damage = C_PackageState.Damage.DAMAGED
	await _pickup(glass)
	assert(CustomerFlowService.confirm_direct_delivery(_actor, customer) == PackageDeliveryCheck.Result.READY)
	assert(second.actual == CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert(GrabService.held_object(_actor) == null, "Refused parcel has actually left the player's hands")
	assert(GrabService.held_relationship(glass) == null)
	assert(ECS.world.entities.has(glass), "Refused parcel remains physical in the warehouse")

	var drop: Vector3 = (customer as Node as Node3D).global_transform * second.definition.refused_parcel_offset
	assert((glass as Node as Node3D).global_position.is_equal_approx(drop), "Customer leaves it next to self")
	assert(CustomerFlowService.confirm_direct_delivery(_actor, customer) == PackageDeliveryCheck.Result.MISSING)
	_level.free()
	ECS.world = null
	print("Customer direct handoff wrong/delivered/refused grip smoke PASS")
	get_tree().quit.call_deferred()


#endregion

#region Ожидание и тестовое размещение
func _waiting_customer() -> E_NpcCharacter:
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		var customer: E_NpcCharacter = CustomerFlowQueries.waiting_customer()
		if customer != null:
			return customer

	assert(false, "Customer must reach service phase within frame budget")
	return null


func _pickup(parcel: Entity) -> void:
	# Тест ставит предмет перед захватом; отказ клиента имеет собственную границу передачи.
	var actor_body: Node3D = _actor as Node as Node3D
	var parcel_body: RigidBody3D = parcel as Node as RigidBody3D
	parcel_body.global_position = actor_body.global_position + PICKUP_OFFSET
	parcel_body.linear_velocity = Vector3.ZERO
	var ray: RayCast3D = GrabService.interaction_raycast(_actor)
	ray.look_at(parcel_body.global_position + Vector3.UP * 0.2)
	for frame: int in 2:
		await get_tree().physics_frame
	assert(GrabService.try_pickup(_actor, parcel))

#endregion
