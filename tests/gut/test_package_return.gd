extends GutTest
## Проверяет утренний возврат фактически отказанной коробки без изменения прежнего расчёта.

var _world: World = null
var _cycle: C_DayCycle = null
var _visit: CustomerVisit = null
var _parcel: Entity = null
var _record: PackageRegistrationRecord = null
var _actor: Entity = null


#region Тестовое окружение
## Создаёт вчерашний отказ, активную регистрацию и коробку утром второго дня.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [
		C_DayCycle.new(),
		C_PackageLedger.new(),
		C_CustomerFlow.new(),
		C_Wallet.new(),
	]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.MORNING
	_cycle.day_index = 2
	_record = PackageRegistrationRecord.new()
	_record.package_id = "refused:1"
	_record.number = 7
	_record.day_index = 1
	(session.get_component(C_PackageLedger) as C_PackageLedger).records.append(_record)
	_visit = CustomerVisit.new()
	_visit.package_id = _record.package_id
	_visit.arrival_day = 1
	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_visit.declaration = CustomerVisit.Declaration.REFUSED
	_visit.settlement_committed = true
	_visit.money_delta = -150
	(session.get_component(C_CustomerFlow) as C_CustomerFlow).visits.append(_visit)
	_parcel = Entity.new()

	var identity: C_Package = C_Package.new()
	identity.package_id = _record.package_id
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	state.registration_number = _record.number
	_parcel.component_resources = [identity, state]
	EntityCompositionFixture.register(_world, _parcel)
	_actor = Entity.new()
	_actor.component_resources = [C_GrabControl.new()]
	_world.add_entity(_actor)


## Удаляет World и сбрасывает глобальную ссылку ECS.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null

#endregion


#region Smart Object actual effect acceptance
## Both native variants execute the actual return through ray eligibility and the common API.
func test_smart_return_variants_commit_parcel_effect_without_reservation_leak() -> void:
	_world.add_observer(O_SmartObject.new())
	for scene_path: String in [
		"res://content/domains/packages/entities/package_return_point.tscn",
		"res://content/domains/packages/entities/package_return_point_wall.tscn",
	]:
		var body: RigidBody3D = RigidBody3D.new()
		body.freeze = true
		body.set_script(E_RigidBodyCharacter)
		var holder: E_RigidBodyCharacter = body as Node as E_RigidBodyCharacter
		var ray: RayCast3D = RayCast3D.new()
		ray.target_position = Vector3(0, 0, -3)
		ray.collision_mask = 8
		ray.enabled = true
		body.add_child(ray)
		holder.interaction_ray_cast = ray
		holder.component_resources = [C_GrabControl.new(), C_Interactor.new()]
		_world.add_entity(holder)
		var prefab: PackedScene = load(scene_path) as PackedScene
		var return_point: Entity = prefab.instantiate() as Entity
		(return_point as Node as Node3D).position = Vector3(0, 0, -1)
		EntityCompositionFixture.register(_world, return_point)
		var grip: R_HeldBy = R_HeldBy.new()
		_parcel.add_relationship(Relationship.new(grip, holder))
		# This fixture derives the cache from its explicit live grip; no physical grab is simulated.
		(holder.get_component(C_GrabControl) as C_GrabControl).held_carry = _parcel
		for frame: int in 3:
			await get_tree().physics_frame
			if ray.is_colliding():
				break
		ray.force_raycast_update()
		assert_true(ray.is_colliding(), "Native return point must be hit by the real query")
		assert_true(
			SmartObjectService.is_available(holder, return_point, &"return_refused_package")
		)
		var receipt: SmartObjectReceipt = SmartObjectService.submit(
			SmartObjectRequest.Operation.USE,
			holder,
			return_point,
			&"return_refused_package",
		)
		assert_eq(receipt.status, SmartObjectReceipt.Status.SUCCEEDED)
		assert_false(_record.active)
		assert_eq(_visit.disposition, CustomerVisit.Disposition.RETURNED)
		assert_eq(_visit.money_delta, -150)
		assert_true(_visit.settlement_committed)
		assert_false(_world.entities.has(_parcel))
		assert_true(holder.relationships.is_empty())
		# Rebuild the existing refused-parcel setup for the second data-only variant.
		_world.remove_entity(return_point)
		_world.remove_entity(holder)
		if scene_path.ends_with("package_return_point.tscn"):
			_record.active = true
			_visit.disposition = CustomerVisit.Disposition.WAREHOUSE
			var identity: C_Package = C_Package.new()
			identity.package_id = _record.package_id
			var state: C_PackageState = C_PackageState.new()
			state.registration = C_PackageState.Registration.REGISTERED
			state.registration_number = _record.number
			_parcel = Entity.new()
			_parcel.component_resources = [identity, state]
			EntityCompositionFixture.register(_world, _parcel)
#endregion


#region Условия возврата и прежний расчёт
## Оба фактических отказа доступны для возврата лишь утром после дня визита.
func test_both_actual_refusal_kinds_are_returnable_next_morning_only() -> void:
	for actual: CustomerVisit.Actual in [
		CustomerVisit.Actual.PLAYER_DENIED,
		CustomerVisit.Actual.CUSTOMER_REFUSED,
	]:
		_visit.actual = actual
		assert_true(PackageReturnService.can_return(_parcel))
		_cycle.day_index = 1
		assert_false(PackageReturnService.can_return(_parcel))
		_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.EVENING
	assert_false(PackageReturnService.can_return(_parcel))
	assert_true(_record.active)


## Заявление терминала не создаёт отказ и не разрешает возврат будущего заказа.
func test_terminal_refused_cannot_invent_actual_refusal_or_return_future_target() -> void:
	_visit.actual = CustomerVisit.Actual.NOT_RESOLVED
	assert_false(PackageReturnService.can_return(_parcel))
	_visit.actual = CustomerVisit.Actual.DELIVERED
	assert_false(PackageReturnService.can_return(_parcel))
	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_visit.arrival_day = 11
	assert_false(PackageReturnService.can_return(_parcel))
	assert_true(_record.active)


## Возврат требует согласованных ID, регистрации и активного номера.
func test_registration_identity_and_active_number_are_required() -> void:
	_record.active = false
	assert_false(PackageReturnService.can_return(_parcel))
	_record.active = true
	_record.number = 8
	assert_false(PackageReturnService.can_return(_parcel))
	_record.number = 7
	_visit.package_id = "different:parcel"
	assert_false(PackageReturnService.can_return(_parcel))
	_visit.package_id = _record.package_id
	(_parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState \
			.Registration \
			.RETURNED
	assert_false(PackageReturnService.can_return(_parcel))


## Возврат без коробки в руках не удаляет предмет, не освобождает номер и не меняет штраф.
func test_unheld_parcel_does_not_exit_release_number_or_change_settlement() -> void:
	assert_true(PackageReturnService.can_return(_parcel))
	assert_false(PackageReturnService.return_held(_actor))
	assert_true(_record.active)
	assert_eq(
		(_parcel.get_component(C_PackageState) as C_PackageState).registration,
		C_PackageState.Registration.REGISTERED,
	)
	assert_eq(_visit.disposition, CustomerVisit.Disposition.WAREHOUSE)
	assert_eq(_visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.REFUSED)
	assert_true(_visit.settlement_committed)
	assert_eq(_visit.money_delta, -150)
	assert_true(_world.entities.has(_parcel))

#endregion
