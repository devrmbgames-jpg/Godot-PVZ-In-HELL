extends GutTest
## Проверяет физическую передачу для осмотра, однократное вскрытие и освобождение занятого имущества.

var _root: Node3D
var _world: World
var _cycle: C_DayCycle
var _visit: CustomerVisit
var _customer: E_NpcCharacter
var _agent: C_CustomerAgent
var _parcel: E_Package


#region Физическое тестовое окружение
## Создаёт World с физическими слотом, кабиной и observers вскрытия и опасностей.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	_world.add_observer(O_PhysicalSlotLifecycle.new())
	_world.add_observer(O_PackageOpening.new())
	_world.add_observer(O_PackageContents.new())
	_world.add_observer(O_CustomerInspectionCargo.new())
	_world.add_observer(O_PackageHazard.new())
	_world.add_observer(O_HazardSpawn.new())
	_world.add_observer(O_ExplosionSetup.new())

	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_CustomerFlow.new(), C_PackageLedger.new()]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_visit = CustomerVisit.new()
	_visit.visit_id = &"inspection"
	_visit.package_id = "inspection-parcel"
	_visit.definition = DEF_Customer.new()
	_visit.definition.private_inspection = true
	_visit.definition.max_followup_visits = 0
	_visit.visit_count = 1
	_visit.started = true
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)

	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30, 0.2, 30)
	collision.shape = shape
	collision.position.y = -0.1
	floor.add_child(collision)
	_root.add_child(floor)

	var counter: E_DeliveryCounter = (load("res://content/domains/customers/entities/delivery_counter.tscn") as PackedScene).instantiate() as E_DeliveryCounter
	_world.add_entity(counter)
	var booth: Entity = (load("res://content/domains/customers/entities/inspection_booth.tscn") as PackedScene).instantiate() as Entity
	(booth as Node as Node3D).position = Vector3(4, 0, 0)
	_world.add_entity(booth)
	_customer = (load("res://content/domains/customers/entities/customer.tscn") as PackedScene).instantiate() as E_NpcCharacter
	(_customer as Node as RigidBody3D).freeze = true
	_world.add_entity(_customer)
	_agent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	_agent.visit_id = _visit.visit_id
	_agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_parcel = (load("res://content/domains/packages/entities/test_bread.tscn") as PackedScene).instantiate() as E_Package
	_parcel.package_definition = _parcel.package_definition.duplicate(true) as DEF_Package
	(_parcel as Node as RigidBody3D).gravity_scale = 0.0
	_world.add_entity(_parcel)
	(_parcel.get_component(C_Package) as C_Package).package_id = _visit.package_id
	(_parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState.Registration.REGISTERED
	CustomerParcelAssignment.bind_parcel(_customer, _visit)


## Удаляет всё тестовое дерево и сбрасывает ECS.world.
func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null


func _borrow() -> void:
	assert_eq(CustomerFlowService._resolve_delivery(_customer, _visit, _parcel, null), PackageDeliveryCheck.Result.READY)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.GOING_TO_BOOTH)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(CustomerInspectionQueries.owner_for(_parcel), _customer)
	assert_true((_parcel as Node as RigidBody3D).freeze)


func _arrive_and_inspect() -> void:
	(_customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.INSPECTING)
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)


func _return() -> void:
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, _visit.definition.inspection_seconds)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	(_customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.RECEIVING)


#endregion

#region Осмотр и фактический исход
## A committed native content fact reserves only the still-current inspection cargo binding.
func test_content_placement_fact_binds_current_inspection_reservation() -> void:
	_borrow()
	var item: Entity = Entity.new()
	_world.add_entity(item)
	var fact: PackageContentPlaced = PackageContentPlaced.new(item, _parcel)
	_world.emit_event(PackageContentPlaced.EVENT, _parcel, fact)
	assert_same(CustomerInspectionQueries.owner_for(item), _customer)


## A delayed fact cannot attach content to a replacement reservation for the same customer.
func test_content_placement_fact_rejects_replaced_inspection_binding() -> void:
	_borrow()
	var item: Entity = Entity.new()
	_world.add_entity(item)
	var fact: PackageContentPlaced = PackageContentPlaced.new(item, _parcel)
	for binding: Relationship in _parcel.relationships.duplicate():
		if binding.relation is R_InspectionCargo:
			_parcel.remove_relationship(binding)
	var replacement: R_InspectionCargo = R_InspectionCargo.new()
	replacement.original_parcel = true
	_parcel.add_relationship(Relationship.new(replacement, _customer))

	_world.emit_event(PackageContentPlaced.EVENT, _parcel, fact)
	assert_null(CustomerInspectionQueries.owner_for(item))
	assert_same(CustomerInspectionQueries.owner_for(_parcel), _customer)


## Removed content is rejected before the owning inspection command receives a freed endpoint.
func test_content_placement_fact_rejects_removed_item() -> void:
	_borrow()
	var item: Entity = Entity.new()
	_world.add_entity(item)
	var fact: PackageContentPlaced = PackageContentPlaced.new(item, _parcel)
	_world.remove_entity(item)
	_world.emit_event(PackageContentPlaced.EVENT, _parcel, fact)
	assert_eq(CustomerInspectionQueries.cargo(_customer).size(), 1)


## Окончательная выдача происходит после возврата из кабины и однократно освобождает её связи.
func test_physical_borrow_finishes_only_after_return_and_kept_parcel_leaves_once() -> void:
	_borrow()
	assert_eq(_customer.get_relationships(Relationship.new(R_InspectingAt.new(), null)).size(), 1)
	assert_eq((PhysicalSlotService.relationship(_parcel).target as E_PhysicalSlot).get_relationships(Relationship.new(R_SlotMountedOn.new(), _customer)).size(), 1)
	_arrive_and_inspect()
	assert_eq((_parcel.get_component(C_PackageState) as C_PackageState).opening, C_PackageState.Opening.CLOSED)
	_return()
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_false(EntityAvailability.contains(_parcel, _world))
	assert_true(CustomerInspectionQueries.cargo(_customer).is_empty())
	assert_true(_customer.get_relationships(Relationship.new(R_InspectingAt.new(), null)).is_empty())
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)


## Отказ возвращает физическую коробку, сохраняя регистрацию и освобождая слот/кабину.
func test_refusal_releases_borrowed_parcel_and_booth_without_losing_registration() -> void:
	_visit.definition.inspection_keep_probability = 0.0
	_borrow()
	_arrive_and_inspect()
	_return()
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_true(EntityAvailability.contains(_parcel, _world))
	assert_eq((_parcel.get_component(C_PackageState) as C_PackageState).registration, C_PackageState.Registration.REGISTERED)
	assert_false((_parcel as Node as RigidBody3D).freeze)
	assert_null(PhysicalSlotService.relationship(_parcel))
	assert_null(CustomerInspectionQueries.owner_for(_parcel))
	assert_true(_customer.get_relationships(Relationship.new(R_InspectingAt.new(), null)).is_empty())


## Реальное вскрытие создаёт содержимое и опасность один раз; при выдаче содержимое уходит с клиентом.
func test_unpack_uses_real_opening_contents_and_hazard_then_keeps_results_once() -> void:
	_visit.definition.inspection_unpack_probability = 1.0
	(_parcel.get_component(C_Package) as C_Package).definition.hazard_on_opened = load("res://content/domains/hazards/entities/explosion.tscn") as PackedScene
	_borrow()
	_arrive_and_inspect()
	assert_eq((_parcel.get_component(C_PackageState) as C_PackageState).opening, C_PackageState.Opening.OPENED)
	assert_eq(_world.query.with_all([C_Explosion]).execute().size(), 1)
	assert_eq(CustomerInspectionQueries.cargo(_customer).size(), 6)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 5)
	PackageLifecycle.publish(_parcel, PackageLifecycleEvent.Kind.Opened, _customer)
	assert_eq(CustomerInspectionQueries.cargo(_customer).size(), 6)
	assert_eq(_world.query.with_all([C_Explosion]).execute().size(), 1)
	_return()
	assert_true(_visit.package_opened)
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_true(_world.query.with_all([C_InventoryItem]).execute().is_empty())


#endregion

#region Освобождение имущества и таймаут
## Принятое во время осмотра содержимое включает ожидающий остаток и не появляется после ухода клиента.
func test_kept_inspection_consumes_pending_contents_before_retry() -> void:
	var queue: C_LootDrops = LootDropService.current()
	queue.placement = queue.placement.duplicate(true) as DEF_ItemPlacement
	queue.placement.initial_budget = 1
	_visit.definition.inspection_unpack_probability = 1.0
	_visit.definition.inspection_keep_probability = 1.0
	_borrow()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_arrive_and_inspect()
	assert_eq(queue.pending.size(), 4)
	assert_eq(CustomerInspectionQueries.cargo(_customer).size(), 2)

	_return()
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_true(queue.pending.is_empty())
	_retry_pending_contents(queue)
	assert_true(_world.query.with_all([C_InventoryItem]).execute().is_empty())

## Позднее размещённое содержимое получает живой резерв осмотра; отказ освобождает все реальные предметы.
func test_late_contents_join_inspection_and_refusal_preserves_them() -> void:
	var queue: C_LootDrops = LootDropService.current()
	queue.placement = queue.placement.duplicate(true) as DEF_ItemPlacement
	queue.placement.initial_budget = 1
	_visit.definition.inspection_unpack_probability = 1.0
	_visit.definition.inspection_keep_probability = 0.0
	_borrow()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_arrive_and_inspect()
	assert_eq(queue.pending.size(), 4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_retry_pending_contents(queue)
	assert_true(queue.pending.is_empty())
	assert_eq(CustomerInspectionQueries.cargo(_customer).size(), 6)
	for item: Entity in _world.query.with_all([C_InventoryItem]).execute():
		assert_same(CustomerInspectionQueries.owner_for(item), _customer)

	_return()
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 5)
	for item: Entity in _world.query.with_all([C_InventoryItem]).execute():
		assert_null(CustomerInspectionQueries.owner_for(item))

## Ночной сброс снимает резервирование; оставшееся содержимое можно забрать в инвентарь.
func test_cleanup_night_releases_unpacked_items_for_player() -> void:
	_visit.definition.inspection_unpack_probability = 1.0
	_visit.definition.inspection_keep_probability = 0.0
	_borrow()
	_arrive_and_inspect()
	var actor: Entity = Entity.new()
	actor.component_resources = [C_Inventory.new()]
	_world.add_entity(actor)

	var contents: Array[Entity] = _world.query.with_all([C_InventoryItem]).execute().duplicate()
	assert_eq(contents.size(), 5)
	assert_false(InventoryService.transfer(contents[0], actor), "Reserved contents cannot be stolen into inventory")
	NightResetService.reset()
	assert_false(EntityAvailability.contains(_customer, _world))
	assert_null(CustomerInspectionQueries.owner_for(_parcel))
	assert_null(PhysicalSlotService.relationship(_parcel))
	assert_false((_parcel as Node as RigidBody3D).freeze)
	assert_true(InventoryService.transfer(contents[0], actor))
	assert_eq(_world.query.with_all([C_InventoryItem]).execute().size(), 5)


## После отказа вскрытое содержимое остаётся доступным предметом без владельца осмотра.
func test_cleanup_refused_unpacked_results_stay_edible_after_return() -> void:
	_visit.definition.inspection_unpack_probability = 1.0
	_visit.definition.inspection_keep_probability = 0.0
	_borrow()
	_arrive_and_inspect()
	_return()
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_true(_visit.package_opened)

	var item: Entity = _world.query.with_all([C_InventoryItem]).execute_one()
	assert_not_null(item)
	assert_null(CustomerInspectionQueries.owner_for(item))
	assert_true(CustomerInspectionQueries.cargo(_customer).is_empty())
	var actor: Entity = Entity.new()
	actor.component_resources = [C_Inventory.new()]
	_world.add_entity(actor)
	assert_true(InventoryService.transfer(item, actor))


## Смерть и удаление участника освобождают слот коробки и резервирование осмотра.
func test_cleanup_customer_death_or_external_removal_releases_physical_borrow() -> void:
	_borrow()
	_customer.add_component(C_Death.new())
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, 0.0)
	assert_true(_visit.customer_dead)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_null(PhysicalSlotService.relationship(_parcel))
	assert_false((_parcel as Node as RigidBody3D).freeze)
	assert_null(CustomerInspectionQueries.owner_for(_parcel))
	# Независимый второй участник проверяет освобождение при штатном удалении из World.
	var second: E_NpcCharacter = (load("res://content/domains/customers/entities/customer.tscn") as PackedScene).instantiate() as E_NpcCharacter
	(second as Node as RigidBody3D).freeze = true
	_world.add_entity(second)

	var next_visit: CustomerVisit = CustomerVisit.new()
	next_visit.definition = _visit.definition
	assert_false(CustomerInspectionService.begin(second, _visit, _parcel), "Closed/dead visit cannot start a new inspection")
	assert_true(CustomerInspectionService.begin(second, next_visit, _parcel))
	_world.remove_entity(second)
	assert_null(PhysicalSlotService.relationship(_parcel))
	assert_false((_parcel as Node as RigidBody3D).freeze)
	assert_null(CustomerInspectionQueries.owner_for(_parcel))


## Недоступная кабина не забирает коробку; таймаут пути завершает осмотр безопасным отказом.
func test_missing_booth_keeps_legacy_handoff_and_walk_timeout_refuses_safely() -> void:
	var booth: Entity = _world.query.with_all([C_InspectionBooth]).execute_one()
	(booth.get_component(C_InspectionBooth) as C_InspectionBooth).enabled = false
	assert_false(CustomerInspectionService.begin(_customer, _visit, _parcel))
	assert_false((_parcel as Node as RigidBody3D).freeze)
	(booth.get_component(C_InspectionBooth) as C_InspectionBooth).enabled = true
	_borrow()
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, _visit.definition.approach_timeout)
	assert_eq(_agent.phase, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH)
	assert_true(_agent.inspection_force_refusal)
	CustomerFlowFixture.advance(CustomerFlowQueries.current(), _cycle, _visit.definition.approach_timeout)
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_null(PhysicalSlotService.relationship(_parcel))

#endregion

#region Реальный scheduling очереди содержимого
func _retry_pending_contents(queue: C_LootDrops) -> void:
	var owner: S_LootDrops = S_LootDrops.new()
	owner.group = "inspection_loot_fixture"
	_world.add_system(owner)
	_world.process(queue.placement.retry_seconds, owner.group)
	_world.remove_system(owner)
#endregion
