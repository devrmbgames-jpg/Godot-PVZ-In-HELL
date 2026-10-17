extends RefCounted
## Читает принятые домашние доставки и их живые связи со встречей.
class_name HomeDeliveryQueries

const _STATUS_TEXT: PackedStringArray = [
	"Принята — доставить до сна",
	"Доставлено",
	"Получатель отказался",
	"Не выполнено",
	"Предложение доставки",
	"Предложение отклонено",
	"Срок предложения истёк",
	"Встреча сорвана",
]


#region Чтение состояния
## Возвращает постоянную запись, включая завершённое обязательство.
## Возвращается общий Resource журнала, не копия; изменять его могут только владельцы операций.
static func find(job_id: StringName) -> NpcHomeDelivery:
	var district: C_District = NpcPopulationQueries.current()
	if district != null:
		for job: NpcHomeDelivery in district.home_deliveries:
			if job.job_id == job_id:
				return job
	return null


## Читает частное предложение для личности и, при обслуживании, конкретного визита.
static func personal_for(npc_id: StringName, visit_id: StringName = &"") -> NpcHomeDelivery:
	var district: C_District = NpcPopulationQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if district == null or cycle == null:
		return null
	for job: NpcHomeDelivery in district.home_deliveries:
		if (
			job.npc_id == npc_id and (visit_id.is_empty() or job.visit_id == visit_id)
			and job.source == NpcHomeDelivery.Source.PERSONAL and available(job)
		):
			return job
	return null


## Читает опубликованные предложения терминала без публикации частных договорённостей.
static func terminal_offers() -> Array[NpcHomeDelivery]:
	var offers: Array[NpcHomeDelivery] = []
	var district: C_District = NpcPopulationQueries.current()
	if district != null:
		for job: NpcHomeDelivery in district.home_deliveries:
			if job.source == NpcHomeDelivery.Source.TERMINAL and job.published and available(job):
				offers.append(job)
	return offers


## Готовит только опубликованные сведения одним проходом по записям; частные данные не попадают в
## UI.
static func published_by_package(
	registry: C_PackageLedger,
	states: Dictionary[String, C_PackageState],
	visits: Dictionary[String, CustomerVisit],
) -> Dictionary[String, TerminalDeliveryInfo]:
	var deliveries_by_package: Dictionary[String, TerminalDeliveryInfo] = { }
	var district: C_District = NpcPopulationQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if district == null or cycle == null or registry == null:
		return deliveries_by_package
	var people: Dictionary[StringName, NpcRecord] = { }
	for person: NpcRecord in district.people:
		people[person.npc_id] = person
	var entries: Dictionary[String, PackageRegistrationRecord] = { }
	for entry: PackageRegistrationRecord in registry.records:
		entries[entry.package_id] = entry
	for job: NpcHomeDelivery in district.home_deliveries:
		if not job.published:
			continue
		var info: TerminalDeliveryInfo = TerminalDeliveryInfo.new()
		info.job_id = job.job_id
		info.published = true
		info.address = NpcPopulationQueries.place_name(job.address_id)
		info.bonus = job.bonus
		info.deadline_day = (
			cycle.day_index + 1
			if job.status == NpcHomeDelivery.Status.OFFERED
			and job.source == NpcHomeDelivery.Source.TERMINAL
			else active_deadline_day(job)
		)
		info.status = job.status
		info.status_text = _STATUS_TEXT[job.status]
		if job.status == NpcHomeDelivery.Status.ACCEPTED and info.deadline_day == 0:
			info.status_text = "Получатель временно недоступен"
		var visit: CustomerVisit = visits.get(job.package_id) as CustomerVisit
		if (
			job.status == NpcHomeDelivery.Status.OFFERED
			and (
				job.day_index == cycle.day_index
				or (
					job.source == NpcHomeDelivery.Source.TERMINAL
					and job.day_index < cycle.day_index
				)
			)
			and cycle.phase != C_DayCycle.Phase.NIGHT and visit != null
		):
			info.can_respond = eligible(
				visit,
				people.get(job.npc_id) as NpcRecord,
				entries.get(job.package_id) as PackageRegistrationRecord,
				states.get(job.package_id) as C_PackageState,
				cycle.day_index,
				job.source,
			)
		deliveries_by_package[job.package_id] = info
	return deliveries_by_package


## Читает действительный личный срок; ноль означает временную недоступность получателя.
static func active_deadline_day(job: NpcHomeDelivery) -> int:
	return HomeDeliveryDeadlineRules.active_deadline_day(
		job,
		NpcPopulationQueries.person_for(job.npc_id),
	)


## Проверяет текущий день и нерешённый заказ предложения.
static func available(job: NpcHomeDelivery) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT
		or job.status != NpcHomeDelivery.Status.OFFERED or job.day_index > cycle.day_index
		or (job.source == NpcHomeDelivery.Source.PERSONAL and job.day_index != cycle.day_index)
	):
		return false
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	return (
		visit != null and visit.package_id == job.package_id
		and visit_available(visit, cycle.day_index, job.source)
	)


## Проверяет пригодность визита по живой коробке и регистрации.
static func visit_available(
	visit: CustomerVisit,
	day_index: int,
	source: NpcHomeDelivery.Source = NpcHomeDelivery.Source.PERSONAL,
) -> bool:
	var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
	var state: C_PackageState = (
		parcel.get_component(C_PackageState) as C_PackageState if parcel != null else null
	)
	return eligible(
		visit,
		NpcPopulationQueries.person_for(visit.customer_id),
		PackageHistoryService.record_for(visit.package_id),
		state,
		day_index,
		source,
	)


## Проверяет пригодность явных записей для домашней доставки.
static func eligible(
	visit: CustomerVisit,
	person: NpcRecord,
	entry: PackageRegistrationRecord,
	state: C_PackageState,
	day_index: int,
	source: NpcHomeDelivery.Source = NpcHomeDelivery.Source.PERSONAL,
) -> bool:
	if (
		person == null or person.profile == null or not person.profile.resident
		or person.death_day != 0 or person.home_id.is_empty()
	):
		return false
	if (
		visit.customer_dead or visit.home_delivery_declined
		or (
			source == NpcHomeDelivery.Source.PERSONAL
			and visit.finished and visit.next_followup_day > day_index
		)
	):
		return false
	if source == NpcHomeDelivery.Source.TERMINAL and day_index >= collection_day(visit):
		return false
	if (
		visit.actual != CustomerVisit.Actual.NOT_RESOLVED
		or visit.declaration != CustomerVisit.Declaration.NONE
		or visit.settlement_committed or visit.complaint != null
	):
		return false
	return (
		entry != null and entry.active and entry.number > 0 and state != null
		and state.registration == C_PackageState.Registration.REGISTERED
		and state.registration_number == entry.number
	)


## Planned personal collection includes an explicitly deferred follow-up.
static func collection_day(visit: CustomerVisit) -> int:
	return maxi(visit.arrival_day, visit.next_followup_day)
#endregion
