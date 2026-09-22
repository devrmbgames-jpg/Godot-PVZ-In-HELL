extends RefCounted
## Sole writer of registration numbers and their explicit warehouse-lifecycle reservations.
class_name PackageRegistrationService


#region Registration API
## Returns the current warehouse ledger, independent of the day index.
static func ledger() -> C_PackageLedger:
	if not is_instance_valid(ECS.world):
		return null
	var session: Entity = ECS.world.query.with_all([C_PackageLedger]).execute_one()
	return session.get_component(C_PackageLedger) as C_PackageLedger if session != null else null


## Requires an active hand scanner, valid parcel and unobstructed scan range.
static func can_scan(actor: Entity, scanner: Entity, target: Entity) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(scanner):
		return false
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(target):
		return false
	var grip: Relationship = S_Grab.held_relationship(scanner)
	if grip == null or grip.target != actor or not scanner.has_component(C_Scanner):
		return false
	if (
		(grip.relation as C_HeldBy).slot == C_Grabbable.HoldSlot.CARRY
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS
	):
		return false
	var cycle: C_DayCycle = S_DayPhase.current()
	if cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or ledger() == null:
		return false
	if not target.has_component(C_Package) or not target.has_component(C_PackageState):
		return false
	var package_state: C_PackageState = target.get_component(C_PackageState)
	if package_state.registration == C_PackageState.Registration.DELIVERED:
		return false
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	if interactor == null or S_InteractionTargeting.find_target(actor, interactor) != target:
		return false
	var ray: RayCast3D = S_Grab.interaction_raycast(actor)
	var config: C_Scanner = scanner.get_component(C_Scanner) as C_Scanner
	return ray.global_position.distance_to(ray.get_collision_point()) <= config.scan_range


## Synchronous command-boundary transaction: no signals/UI/await before all writes finish.
static func scan(actor: Entity, scanner: Entity, target: Entity) -> PackageScanResult:
	var result: PackageScanResult = PackageScanResult.new()
	if not can_scan(actor, scanner, target):
		return result
	var identity: C_Package = target.get_component(C_Package) as C_Package
	var state: C_PackageState = target.get_component(C_PackageState) as C_PackageState
	var registry: C_PackageLedger = ledger()
	result.package_id = identity.package_id
	for record: PackageRegistrationRecord in registry.records:
		if record.package_id == identity.package_id:
			if not record.active:
				return result
			result.outcome = PackageScanResult.Outcome.ALREADY_REGISTERED
			result.number = record.number
			result.message = "Уже учтена · №%03d" % record.number
			return result
	if identity.package_id.is_empty() or identity.definition == null:
		return result
	if state.scan == C_PackageState.Scan.SCANNED or state.registration_number != 0:
		result.message = "Ошибка реестра: запись отсутствует"
		return result
	var cycle: C_DayCycle = S_DayPhase.current()

	var sequence: int = smallest_free_number(registry)

	var registration: PackageRegistrationRecord = PackageRegistrationRecord.new()
	registration.package_id = identity.package_id
	registration.day_index = cycle.day_index
	registration.number = sequence
	registration.definition = identity.definition
	registry.records.append(registration)
	state.registration_number = registration.number
	state.registration_day = cycle.day_index
	state.scan = C_PackageState.Scan.SCANNED
	state.registration = C_PackageState.Registration.REGISTERED
	result.outcome = PackageScanResult.Outcome.REGISTERED
	result.number = registration.number
	result.message = "Зарегистрирована · №%03d" % registration.number
	return result


## Finds the smallest unreserved positive base number; suffixes and days are irrelevant.
static func smallest_free_number(registry: C_PackageLedger) -> int:
	var occupied: Dictionary[int, bool] = { }
	for record: PackageRegistrationRecord in registry.records:
		if record.active:
			occupied[record.number] = true

	var candidate: int = 1
	while occupied.has(candidate):
		candidate += 1

	return candidate


## Called after actual delivery marks DELIVERED; UI declarations cannot free numbers.
## Node removal, damage, missing parcels and day changes do not imply warehouse departure.
static func release_number(parcel: Entity) -> bool:
	if not is_instance_valid(parcel):
		return false

	var identity: C_Package = parcel.get_component(C_Package)
	var state: C_PackageState = parcel.get_component(C_PackageState)
	var registry: C_PackageLedger = ledger()
	if identity == null or state == null or registry == null:
		return false
	if state.registration != C_PackageState.Registration.DELIVERED:
		return false

	for record: PackageRegistrationRecord in registry.records:
		if record.package_id == identity.package_id and record.active:
			record.active = false
			registry.last_departed_package_id = identity.package_id
			return true

	return false
#endregion


#region Read-only terminal view
## Presents all active registrations and the last departure, including older-day parcels.
static func terminal_text() -> String:
	var registry: C_PackageLedger = ledger()
	if registry == null:
		return "Реестр недоступен"
	var states: Dictionary[String, C_PackageState] = { }
	for parcel: Entity in ECS.world.query.with_all([C_Package, C_PackageState]).execute():
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		states[identity.package_id] = parcel.get_component(C_PackageState) as C_PackageState
	var lines: PackedStringArray = []
	var ordered: Array[PackageRegistrationRecord] = registry.records.duplicate()
	ordered.sort_custom(_record_before)
	for record: PackageRegistrationRecord in ordered:
		if not record.active and record.package_id != registry.last_departed_package_id:
			continue
		var definition: DEF_Package = record.definition
		var state: C_PackageState = states.get(record.package_id) as C_PackageState
		var status: String = "Нет в ПВЗ" if state == null else _status_text(state)
		if not record.active:
			status = "Выдана · последняя завершённая"
		lines.append(
			"№%03d   ·   %s\n%s\n%s\n%s"
			% [
				record.number,
				status,
				definition.description,
				definition.comment,
				_tag_text(definition),
			]
		)
	return (
		"\n\n────────────────────────────────────────\n\n".join(lines)
		if not lines.is_empty()
		else (
			"Пока нет зарегистрированных посылок.\n\n"
			+ "Возьмите сканер и нажмите ЛКМ, глядя на коробку."
		)
	)


static func _record_before(
	first: PackageRegistrationRecord,
	second: PackageRegistrationRecord,
) -> bool:
	if first.number != second.number:
		return first.number < second.number

	return first.active and not second.active


static func _status_text(state: C_PackageState) -> String:
	var delivered: bool = state.registration == C_PackageState.Registration.DELIVERED
	var parts: PackedStringArray = ["Выдана" if delivered else "Зарегистрирована"]
	if state.damage == C_PackageState.Damage.DAMAGED:
		parts.append("Повреждена")
	elif state.damage == C_PackageState.Damage.DESTROYED:
		parts.append("Разрушена")
	if state.opening == C_PackageState.Opening.OPENED:
		parts.append("Вскрыта")
	return " · ".join(parts)


static func _tag_text(definition: DEF_Package) -> String:
	var tags: PackedStringArray = []
	if definition.tags & DEF_Package.Tag.FRAGILE:
		tags.append("Хрупкое")
	if definition.tags & DEF_Package.Tag.HEAVY:
		tags.append("Тяжёлое")
	if definition.tags & DEF_Package.Tag.LIQUID:
		tags.append("Жидкость")
	if definition.hazard != DEF_Package.Hazard.NONE:
		tags.append("Опасное содержимое")
	return " / ".join(tags) if not tags.is_empty() else "Обычная посылка"
#endregion
