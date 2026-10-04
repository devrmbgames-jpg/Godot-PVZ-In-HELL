extends RefCounted
## Explicit physical Morning exit. Terminal declarations alone never release a number.
class_name PackageReturnService


static func held_refused(actor: Entity) -> Entity:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING or not GrabService.holder_available(actor):
		return null

	for slot: int in 3:
		var parcel: Entity = GrabService.held_in_slot(actor, slot)
		if can_return(parcel):
			return parcel
	return null


static func can_return(parcel: Entity) -> bool:
	var cycle: C_DayCycle = DayPhaseService.current()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
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

	for visit: CustomerVisit in CustomerFlowService.current().visits:
		if visit.package_id == identity.package_id and visit.disposition == CustomerVisit.Disposition.WAREHOUSE:
			visit.disposition = CustomerVisit.Disposition.RETURNED
			visit.next_followup_day = 0
	# Keep actual/declaration, dispute and settlement records unchanged.
	GrabService.release(actor, parcel)
	ECS.world.remove_entity(parcel)
	return true
