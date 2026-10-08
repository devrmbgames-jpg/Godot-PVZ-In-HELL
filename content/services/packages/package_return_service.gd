extends RefCounted
## Возвращает физическую коробку утром; одно заявление в терминале не освобождает её номер.
class_name PackageReturnService


#region Утренний физический возврат
## Утром находит удерживаемую игроком коробку, допустимую к физическому возврату.
static func held_refused(actor: Entity) -> Entity:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING or not GrabService.holder_available(actor):
		return null

	for slot: int in 3:
		var parcel: Entity = GrabService.held_in_slot(actor, slot)
		if can_return(parcel):
			return parcel
	return null


## Проверяет активную регистрацию и прошлый отказ с оставшейся на складе коробкой.
static func can_return(parcel: Entity) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var ledger: C_PackageLedger = PackageQueries.ledger()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING or flow == null or ledger == null or not EntityAvailability.contains(parcel, ECS.world):
		return false

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	if identity == null or state == null or state.registration != C_PackageState.Registration.REGISTERED:
		return false

	var registered: bool = false
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == identity.package_id and record.active and record.number == state.registration_number:
			registered = true
	if not registered:
		return false

	for visit: CustomerVisit in flow.visits:
		if visit.package_id == identity.package_id and visit.arrival_day < cycle.day_index and visit.disposition == CustomerVisit.Disposition.WAREHOUSE and visit.actual in [CustomerVisit.Actual.PLAYER_DENIED, CustomerVisit.Actual.CUSTOMER_REFUSED]:
			return true
	return false


## Возвращает удерживаемую коробку: освобождает номер, отменяет повтор и удаляет физический предмет.
static func return_held(actor: Entity) -> bool:
	var parcel: Entity = held_refused(actor)
	if parcel == null:
		return false

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	state.registration = C_PackageState.Registration.RETURNED
	if not PackageRegistrationService.release_number(parcel):
		state.registration = C_PackageState.Registration.REGISTERED
		return false

	for visit: CustomerVisit in CustomerFlowQueries.current().visits:
		if visit.package_id == identity.package_id and visit.disposition == CustomerVisit.Disposition.WAREHOUSE:
			visit.disposition = CustomerVisit.Disposition.RETURNED
			visit.next_followup_day = 0
	# Фактический исход, заявление, спор и записи расчёта сохраняются при возврате.
	GrabService.release(actor, parcel)
	ECS.world.remove_entity(parcel)
	return true

#endregion
