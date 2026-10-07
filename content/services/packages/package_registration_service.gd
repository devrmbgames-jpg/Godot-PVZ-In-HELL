extends RefCounted
## Единственный владелец записи регистрационных номеров и их складских резервов.
class_name PackageRegistrationService


#region Регистрация и складской резерв
## Находит живую коробку по постоянному package_id, отдельно от номера регистрации.
static func find_live_package(package_id: String) -> Entity:
	if not is_instance_valid(ECS.world):
		return null

	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		if identity != null and identity.package_id == package_id:
			return parcel
	return null


## Читает журнал текущего склада, независимо от номера дня.
static func ledger() -> C_PackageLedger:
	if not is_instance_valid(ECS.world):
		return null

	var session: Entity = ECS.world.query.with_all([C_PackageLedger]).execute_one()
	return session.get_component(C_PackageLedger) as C_PackageLedger if session != null else null


## Возвращает соответствие ID живым C_PackageState для чтения интерфейсом; ссылки компонентов не являются копиями.
static func live_states() -> Dictionary[String, C_PackageState]:
	var result: Dictionary[String, C_PackageState] = {}
	if not is_instance_valid(ECS.world):
		return result

	for parcel: Entity in ECS.world.query.with_all([C_Package, C_PackageState]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
		result[identity.package_id] = state
	return result


## Требует сканер в руке, доступную коробку под лучом и дистанцию scan_range.
static func can_scan(actor: Entity, scanner: Entity, target: Entity) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(scanner):
		return false
	if not GrabService.holder_available(actor) or not GrabService.entity_available(target):
		return false

	var grip: Relationship = GrabService.held_relationship(scanner)
	if grip == null or grip.target != actor or not scanner.has_component(C_Scanner):
		return false
	if (
		(grip.relation as R_HeldBy).slot == C_Grabbable.HoldSlot.CARRY
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS
	):
		return false

	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or ledger() == null:
		return false
	if not target.has_component(C_Package) or not target.has_component(C_PackageState):
		return false

	var package_state: C_PackageState = target.get_component(C_PackageState)
	if package_state.registration >= C_PackageState.Registration.DELIVERED:
		return false

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null or InteractionTargetingService.find_target(actor, interactor) != target:
		return false

	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	var config: C_Scanner = scanner.get_component(C_Scanner) as C_Scanner
	return ray.global_position.distance_to(ray.get_collision_point()) <= config.scan_range


## Проверяет применение сканера, затем передаёт регистрацию в register_package().
static func scan(actor: Entity, scanner: Entity, target: Entity) -> PackageScanResult:
	if not can_scan(actor, scanner, target):
		return PackageScanResult.new()
	return register_package(target)


## Синхронно регистрирует коробку для доверенных игровых и отладочных вызовов.
## Проверки удержания сканера и дистанции выполняются в scan().
static func register_package(target: Entity) -> PackageScanResult:
	var result: PackageScanResult = PackageScanResult.new()
	if not EntityAvailability.contains(target, ECS.world):
		return result
	if not target.has_component(C_Package) or not target.has_component(C_PackageState):
		return result

	var registry: C_PackageLedger = ledger()
	var cycle: C_DayCycle = DayPhaseService.current()
	if registry == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return result

	var identity: C_Package = target.get_component(C_Package) as C_Package
	var state: C_PackageState = target.get_component(C_PackageState) as C_PackageState
	result.package_id = identity.package_id
	var registration: PackageRegistrationRecord = PackageHistoryService.record_for(identity.package_id, registry)
	if registration != null:
		if not registration.active:
			return result
		if registration.number > 0:
			result.outcome = PackageScanResult.Outcome.ALREADY_REGISTERED
			result.number = registration.number
			result.message = "Уже учтена · №%03d" % registration.number
			return result

	if identity.package_id.is_empty() or identity.definition == null:
		return result
	if state.registration >= C_PackageState.Registration.DELIVERED:
		return result
	if state.scan == C_PackageState.Scan.SCANNED or state.registration_number != 0:
		result.message = "Ошибка реестра: запись отсутствует"
		return result
	if CustomerFlowService.package_declared_lost(identity.package_id):
		result.message = "Посылка уже заявлена потерянной"
		return result

	var sequence: int = smallest_free_number(registry)
	if registration == null:
		var received_day: int = identity.delivery_day if identity.delivery_day > 0 else cycle.day_index
		registration = PackageHistoryService.record_arrival(target, received_day)
		if registration == null:
			return result
	registration.day_index = cycle.day_index
	registration.number = sequence
	state.registration_number = registration.number
	state.registration_day = cycle.day_index
	state.scan = C_PackageState.Scan.SCANNED
	state.registration = C_PackageState.Registration.REGISTERED
	result.outcome = PackageScanResult.Outcome.REGISTERED
	result.number = registration.number
	result.message = "Зарегистрирована · №%03d" % registration.number
	NpcDeliveryOfferService.refresh()
	ECS.world.emit_event(PackageScanResult.EVENT, target, result)
	return result


## Находит наименьший свободный положительный номер среди активных записей, независимо от дня.
static func smallest_free_number(registry: C_PackageLedger) -> int:
	var occupied: Dictionary[int, bool] = { }
	for record: PackageRegistrationRecord in registry.records:
		if record.active and record.number > 0:
			occupied[record.number] = true

	var candidate: int = 1
	while occupied.has(candidate):
		candidate += 1

	return candidate


## Освобождает номер после явного DELIVERED, RETURNED или BOUGHT_OUT; заявление игрока его не освобождает.
## Удаление Node, повреждение, пропажа коробки и смена дня не подтверждают уход со склада.
static func release_number(parcel: Entity) -> bool:
	if not is_instance_valid(parcel):
		return false

	var identity: C_Package = parcel.get_component(C_Package)
	var state: C_PackageState = parcel.get_component(C_PackageState)
	var registry: C_PackageLedger = ledger()
	if identity == null or state == null or registry == null:
		return false
	if state.registration < C_PackageState.Registration.DELIVERED:
		return false

	for record: PackageRegistrationRecord in registry.records:
		if record.package_id == identity.package_id and record.active:
			record.active = false
			record.departure = state.registration
			registry.last_departed_package_id = identity.package_id
			return true

	return false
#endregion
