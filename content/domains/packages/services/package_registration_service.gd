extends RefCounted
## Единственный владелец записи регистрационных номеров и их складских резервов.
class_name PackageRegistrationService


#region Регистрация и складской резерв
## Требует сканер в руке, доступную коробку под лучом и дистанцию scan_range.
static func can_scan(actor: Entity, scanner: Entity, target: Entity) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(scanner):
		return false
	if not GrabQueries.holder_available(actor) or not GrabQueries.entity_available(target):
		return false

	var grip: Relationship = GrabQueries.held_relationship(scanner)
	if grip == null or grip.target != actor or not scanner.has_component(C_Scanner):
		return false
	if (
		(grip.relation as R_HeldBy).slot == C_Grabbable.HoldSlot.CARRY
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS
	):
		return false

	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or PackageQueries.ledger() == null:
		return false
	if not target.has_component(C_Package) or not target.has_component(C_PackageState):
		return false

	var package_state: C_PackageState = target.get_component(C_PackageState)
	if package_state.registration >= C_PackageState.Registration.DELIVERED:
		return false

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null or InteractionTargetingGeometry.find_target(actor, interactor) != target:
		return false

	var ray: RayCast3D = GrabQueries.interaction_raycast(actor)
	var config: C_Scanner = scanner.get_component(C_Scanner) as C_Scanner
	return ray.global_position.distance_to(ray.get_collision_point()) <= config.scan_range


## Читает уже выделенный номер, не меняя регистрацию/дату и не публикуя регистрацию повторно.
## Успешное чтение фиксирует только scan; незарегистрированная коробка не получает номер от сканера.
static func scan(actor: Entity, scanner: Entity, target: Entity) -> PackageScanResult:
	if not can_scan(actor, scanner, target):
		return PackageScanResult.new()
	var result: PackageScanResult = PackageScanResult.new()
	var identity: C_Package = target.get_component(C_Package) as C_Package
	var state: C_PackageState = target.get_component(C_PackageState) as C_PackageState
	result.package_id = identity.package_id
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(identity.package_id)
	if (
		record == null or not record.active or record.number <= 0
		or state.registration != C_PackageState.Registration.REGISTERED
		or state.registration_number != record.number or state.registration_day != record.day_index
	):
		result.message = "Посылка не зарегистрирована при поступлении"
		return result
	state.scan = C_PackageState.Scan.SCANNED
	result.outcome = PackageScanResult.Outcome.ALREADY_REGISTERED
	result.number = record.number
	result.message = "Номер посылки · №%03d" % record.number
	return result


## Синхронно регистрирует коробку для доверенных игровых и отладочных вызовов.
## Не фиксирует использование сканера; scan() только читает готовую регистрацию.
## REGISTERED фиксирует номер/state до события; publish_event=false оставляет публикацию caller.
## Receiving завершает свой manifest до публикации, restore сверяет записи без replay события.
## ALREADY_REGISTERED возвращает прежний номер без события.
static func register_package(target: Entity, publish_event: bool = true) -> PackageScanResult:
	var scan_receipt: PackageScanResult = PackageScanResult.new()
	if not EntityAvailability.contains(target, ECS.world):
		return scan_receipt
	if not target.has_component(C_Package) or not target.has_component(C_PackageState):
		return scan_receipt

	var registry: C_PackageLedger = PackageQueries.ledger()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if registry == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT:
		return scan_receipt

	var identity: C_Package = target.get_component(C_Package) as C_Package
	var state: C_PackageState = target.get_component(C_PackageState) as C_PackageState
	scan_receipt.package_id = identity.package_id
	var registration: PackageRegistrationRecord = (
		PackageHistoryService.record_for(identity.package_id, registry)
	)
	if registration != null:
		if not registration.active:
			return scan_receipt
		if registration.number > 0:
			scan_receipt.outcome = PackageScanResult.Outcome.ALREADY_REGISTERED
			scan_receipt.number = registration.number
			scan_receipt.message = "Уже учтена · №%03d" % registration.number
			return scan_receipt

	if identity.package_id.is_empty() or identity.definition == null:
		return scan_receipt
	if state.registration >= C_PackageState.Registration.DELIVERED:
		return scan_receipt
	if state.scan == C_PackageState.Scan.SCANNED or state.registration_number != 0:
		scan_receipt.message = "Ошибка реестра: запись отсутствует"
		return scan_receipt
	if CustomerFlowQueries.package_declared_lost(identity.package_id):
		scan_receipt.message = "Посылка уже заявлена потерянной"
		return scan_receipt

	var sequence: int = smallest_free_number(registry)
	if registration == null:
		var received_day: int = (
			identity.delivery_day if identity.delivery_day > 0 else cycle.day_index
		)
		registration = PackageHistoryService.record_arrival(target, received_day)
		if registration == null:
			return scan_receipt
	registration.day_index = cycle.day_index
	registration.number = sequence
	state.registration_number = registration.number
	state.registration_day = cycle.day_index
	state.registration = C_PackageState.Registration.REGISTERED
	scan_receipt.outcome = PackageScanResult.Outcome.REGISTERED
	scan_receipt.number = registration.number
	scan_receipt.message = "Зарегистрирована · №%03d" % registration.number
	if publish_event:
		ECS.world.emit_event(PackageScanResult.EVENT, target, scan_receipt)
	return scan_receipt


## Однократная сверка после overlay снимка, до readiness/planning; не scheduled обход.
## Регистрирует только живые коробки действующих поступлений без номера в порядке ledger.
## Старые отсутствующие/закрытые/объявленные LOST коробки не создаются и не регистрируются.
## Возвращает число новых номеров; события не повторяются, даты существующих номеров сохраняются.
static func reconcile_received() -> int:
	var ledger: C_PackageLedger = PackageQueries.ledger()
	if ledger == null:
		return 0
	var registered: int = 0
	for record: PackageRegistrationRecord in ledger.records:
		if not record.active or record.number != 0 or record.received_day < 1:
			continue
		var parcel: Entity = PackageQueries.find_live_package(record.package_id)
		if parcel == null:
			continue
		var receipt: PackageScanResult = register_package(parcel, false)
		if receipt.outcome == PackageScanResult.Outcome.REGISTERED:
			registered += 1
	return registered


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


## Освобождает номер после явного DELIVERED, RETURNED или BOUGHT_OUT; заявление игрока его не
## освобождает.
## Удаление Node, повреждение, пропажа коробки и смена дня не подтверждают уход со склада.
static func release_number(parcel: Entity) -> bool:
	if not is_instance_valid(parcel):
		return false

	var identity: C_Package = parcel.get_component(C_Package)
	var state: C_PackageState = parcel.get_component(C_PackageState)
	var registry: C_PackageLedger = PackageQueries.ledger()
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
