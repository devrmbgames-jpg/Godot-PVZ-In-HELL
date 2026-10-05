extends RefCounted
## Создаёт сохраняемые предложения по событиям регистрации и утра, без AI polling.
class_name NpcDeliveryOfferService

const PERSONAL_DELAY_MIN: int = 1
const PERSONAL_DELAY_MAX: int = 3
const PERCENT_SCALE: int = 100
const STATUS_TEXT: PackedStringArray = [
	"Принята — доставить до сна", "Доставлено", "Получатель отказался", "Не выполнено",
	"Предложение доставки", "Предложение отклонено", "Срок предложения истёк",
	"Встреча сорвана",
]

#region Ежедневный выбор
## Готовит выбор для явного утра, включая ночную подготовку до изменения DayCycle.
static func prepare_day(day_index: int) -> void:
	var district: C_District = DistrictPopulationService.current()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	var registry: C_PackageLedger = PackageRegistrationService.ledger()
	if district == null or district.definition == null or day_index < 1 or district.delivery_offer_day > day_index:
		return
	if district.delivery_offer_day != day_index:
		district.delivery_offer_day = day_index
		district.delivery_considered.clear()
		var settings: DEF_District = district.definition
		var minimum: int = clampi(settings.terminal_delivery_minimum, 0, 3)
		var maximum: int = clampi(settings.terminal_delivery_maximum, minimum, 3)
		district.terminal_offer_target = _random("terminal/%d" % day_index).randi_range(minimum, maximum)
	if flow == null or registry == null:
		return

	var people: Dictionary[StringName, NpcRecord] = {}
	for person: NpcRecord in district.people:
		people[person.npc_id] = person
	var entries: Dictionary[String, PackageRegistrationRecord] = {}
	for entry: PackageRegistrationRecord in registry.records:
		entries[entry.package_id] = entry
	var claimed: Dictionary[String, bool] = {}
	var terminal_count: int = 0
	var personal_count: int = 0
	for job: NpcHomeDelivery in district.home_deliveries:
		claimed[job.package_id] = true
		if job.day_index == day_index:
			if job.source == NpcHomeDelivery.Source.TERMINAL:
				terminal_count += 1
			else:
				personal_count += 1
	var states: Dictionary[String, C_PackageState] = PackageRegistrationService.live_states()
	for visit: CustomerVisit in flow.visits:
		if claimed.has(visit.package_id) or district.delivery_considered.has(String(visit.visit_id)):
			continue
		var person: NpcRecord = people.get(visit.customer_id) as NpcRecord
		var entry: PackageRegistrationRecord = entries.get(visit.package_id) as PackageRegistrationRecord
		var state: C_PackageState = states.get(visit.package_id) as C_PackageState
		if not _eligible(visit, person, entry, state, day_index):
			continue
		district.delivery_considered.append(String(visit.visit_id))
		var personal: bool = personal_count < district.definition.personal_delivery_daily_minimum
		personal = (personal or _random("personal/%d/%s" % [day_index, visit.visit_id]).randf() < district.definition.personal_delivery_probability) and not NpcSocialService.distrusts_player(person)
		if personal:
			_create(district, visit, person, entry, day_index, NpcHomeDelivery.Source.PERSONAL, personal_count == 0)
			claimed[visit.package_id] = true
			personal_count += 1
		elif terminal_count < district.terminal_offer_target:
			_create(district, visit, person, entry, day_index, NpcHomeDelivery.Source.TERMINAL)
			claimed[visit.package_id] = true
			terminal_count += 1

## Обновляет только текущий игровой день; ночью выбором владеет prepare_day.
static func refresh() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null and cycle.phase != C_DayCycle.Phase.NIGHT:
		prepare_day(cycle.day_index)
#endregion

#region Чтение предложений
## Возвращает постоянную запись, включая завершённое обязательство.
static func find(job_id: StringName) -> NpcHomeDelivery:
	var district: C_District = DistrictPopulationService.current()
	if district != null:
		for job: NpcHomeDelivery in district.home_deliveries:
			if job.job_id == job_id:
				return job
	return null

## Читает частное предложение для личности и, при обслуживании, конкретного визита.
static func personal_for(npc_id: StringName, visit_id: StringName = &"") -> NpcHomeDelivery:
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if district == null or cycle == null:
		return null
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.npc_id == npc_id and (visit_id.is_empty() or job.visit_id == visit_id) and job.source == NpcHomeDelivery.Source.PERSONAL and _available(job):
			return job
	return null

## Читает опубликованные предложения терминала без публикации частных договорённостей.
static func terminal_offers() -> Array[NpcHomeDelivery]:
	var result: Array[NpcHomeDelivery] = []
	var district: C_District = DistrictPopulationService.current()
	if district != null:
		for job: NpcHomeDelivery in district.home_deliveries:
			if job.source == NpcHomeDelivery.Source.TERMINAL and job.published and _available(job):
				result.append(job)
	return result

## Готовит только опубликованные сведения одним проходом по записям; частные данные не попадают в UI.
static func published_by_package(registry: C_PackageLedger, states: Dictionary[String, C_PackageState], visits: Dictionary[String, CustomerVisit]) -> Dictionary[String, TerminalDeliveryInfo]:
	var result: Dictionary[String, TerminalDeliveryInfo] = {}
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if district == null or cycle == null or registry == null:
		return result
	var people: Dictionary[StringName, NpcRecord] = {}
	for person: NpcRecord in district.people:
		people[person.npc_id] = person
	var entries: Dictionary[String, PackageRegistrationRecord] = {}
	for entry: PackageRegistrationRecord in registry.records:
		entries[entry.package_id] = entry
	for job: NpcHomeDelivery in district.home_deliveries:
		if not job.published:
			continue
		var info: TerminalDeliveryInfo = TerminalDeliveryInfo.new()
		info.job_id = job.job_id
		info.published = true
		info.address = DistrictPopulationService.place_name(job.address_id)
		info.bonus = job.bonus
		info.deadline_day = job.deadline_day
		info.status = job.status
		info.status_text = STATUS_TEXT[job.status]
		var visit: CustomerVisit = visits.get(job.package_id) as CustomerVisit
		if job.status == NpcHomeDelivery.Status.OFFERED and job.day_index == cycle.day_index and cycle.phase != C_DayCycle.Phase.NIGHT and visit != null:
			info.can_respond = _eligible(
				visit, people.get(job.npc_id) as NpcRecord,
				entries.get(job.package_id) as PackageRegistrationRecord,
				states.get(job.package_id) as C_PackageState, cycle.day_index,
			)
		result[job.package_id] = info
	return result
#endregion

#region Решения игрока и сценария
## Принимает запрос терминала только для явно опубликованной записи.
static func respond_published(job_id: StringName, accept_delivery: bool) -> bool:
	var job: NpcHomeDelivery = find(job_id)
	if job == null or not job.published:
		return false
	return accept(job_id) if accept_delivery else decline(job_id)

## Явно назначает личное предложение реальному заказу; повтор сценария возвращает ту же запись.
static func assign_personal(visit_id: StringName, scenario_id: StringName = &"", published: bool = false) -> NpcHomeDelivery:
	var visit: CustomerVisit = CustomerFlowService.find_visit(visit_id)
	var district: C_District = DistrictPopulationService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if visit == null or district == null or cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or not _visit_available(visit, cycle.day_index):
		return null
	prepare_day(cycle.day_index)
	for previous: NpcHomeDelivery in district.home_deliveries:
		if previous.package_id != visit.package_id:
			continue
		if previous.day_index != cycle.day_index or previous.status != NpcHomeDelivery.Status.OFFERED:
			return null
		if not previous.scenario_id.is_empty() and previous.scenario_id != scenario_id:
			return null
		if previous.source == NpcHomeDelivery.Source.TERMINAL:
			previous.base_bonus = maxi(0, visit.payment)
			previous.bonus = previous.base_bonus
		previous.source = NpcHomeDelivery.Source.PERSONAL
		previous.published = published
		previous.scenario_id = scenario_id
		return previous
	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
	var entry: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
	var job: NpcHomeDelivery = _create(district, visit, person, entry, cycle.day_index, NpcHomeDelivery.Source.PERSONAL)
	job.scenario_id = scenario_id
	job.published = published
	if not district.delivery_considered.has(String(visit_id)):
		district.delivery_considered.append(String(visit_id))
	return job

## Принимает предложение без общего лимита обязательств; повтор не меняет визит и деньги.
static func accept(job_id: StringName) -> bool:
	var job: NpcHomeDelivery = find(job_id)
	if job == null:
		return false
	if job.status == NpcHomeDelivery.Status.ACCEPTED:
		return true
	if not _available(job):
		return false
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	job.status = NpcHomeDelivery.Status.ACCEPTED
	visit.next_followup_day = job.deadline_day
	visit.followup_committed = true
	_finish_visit(visit)
	return true

## Отказ от терминала не переносит визит; личный отказ сохраняет договорённость зайти самому.
static func decline(job_id: StringName) -> bool:
	var job: NpcHomeDelivery = find(job_id)
	if job == null:
		return false
	if job.status == NpcHomeDelivery.Status.DECLINED:
		return true
	if not _available(job):
		return false
	job.status = NpcHomeDelivery.Status.DECLINED
	if job.source == NpcHomeDelivery.Source.PERSONAL:
		var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
		var delay: int = _random("return/" + String(job.job_id)).randi_range(PERSONAL_DELAY_MIN, PERSONAL_DELAY_MAX)
		visit.home_delivery_declined = true
		visit.next_followup_day = job.day_index + delay
		visit.arrival_day = visit.next_followup_day
		visit.followup_committed = true
		_finish_visit(visit)
	return true

## Один раз просит повысить личную доплату; ответ и сумма не перебрасываются.
static func negotiate(job_id: StringName) -> NpcHomeDelivery.Bargain:
	var job: NpcHomeDelivery = find(job_id)
	var district: C_District = DistrictPopulationService.current()
	if job == null or district == null or job.source != NpcHomeDelivery.Source.PERSONAL:
		return NpcHomeDelivery.Bargain.NONE
	if job.bargain != NpcHomeDelivery.Bargain.NONE:
		return job.bargain
	if not _available(job):
		return NpcHomeDelivery.Bargain.NONE
	job.bargain = NpcHomeDelivery.Bargain.DECLINED
	if job.bargain_roll < district.definition.delivery_bargain_probability:
		job.bargain = NpcHomeDelivery.Bargain.ACCEPTED
		job.bonus = floori(float(job.base_bonus) * district.definition.delivery_bargain_percent / PERCENT_SCALE)
	return job.bargain
#endregion

#region Пригодность и создание
static func _available(job: NpcHomeDelivery) -> bool:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT or job.day_index != cycle.day_index or job.status != NpcHomeDelivery.Status.OFFERED:
		return false
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	return visit != null and visit.package_id == job.package_id and _visit_available(visit, cycle.day_index)

static func _visit_available(visit: CustomerVisit, day_index: int) -> bool:
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState if parcel != null else null
	return _eligible(visit, DistrictPopulationService.person_for(visit.customer_id), PackageHistoryService.record_for(visit.package_id), state, day_index)

static func _eligible(visit: CustomerVisit, person: NpcRecord, entry: PackageRegistrationRecord, state: C_PackageState, day_index: int) -> bool:
	if person == null or person.profile == null or not person.profile.resident or person.death_day != 0 or person.home_id.is_empty():
		return false
	if visit.customer_dead or visit.home_delivery_declined or visit.arrival_day > day_index or (visit.finished and visit.next_followup_day > day_index):
		return false
	if visit.actual != CustomerVisit.Actual.NOT_RESOLVED or visit.declaration != CustomerVisit.Declaration.NONE or visit.settlement_committed or visit.complaint != null:
		return false
	return entry != null and entry.active and entry.number > 0 and state != null and state.registration == C_PackageState.Registration.REGISTERED and state.registration_number == entry.number

static func _create(district: C_District, visit: CustomerVisit, person: NpcRecord, entry: PackageRegistrationRecord, day_index: int, source: NpcHomeDelivery.Source, first_personal: bool = false) -> NpcHomeDelivery:
	var job: NpcHomeDelivery = NpcHomeDelivery.new()
	job.job_id = StringName("home/%d/%s" % [day_index, visit.visit_id])
	job.npc_id = person.npc_id
	job.visit_id = visit.visit_id
	job.package_id = visit.package_id
	job.package_history_id = entry.history_id
	job.address_id = person.home_id
	job.order_number = entry.number
	job.day_index = day_index
	job.deadline_day = day_index + 1
	job.source = source
	if first_personal and district.definition.force_personal_delivery_scenario and district.definition.personal_delivery_scenario != null:
		job.scenario_id = district.definition.personal_delivery_scenario.key
	job.published = source == NpcHomeDelivery.Source.TERMINAL
	job.status = NpcHomeDelivery.Status.OFFERED
	job.base_bonus = maxi(0, district.definition.terminal_delivery_bonus if source == NpcHomeDelivery.Source.TERMINAL and district.definition.terminal_delivery_bonus >= 0 else visit.payment)
	job.bonus = job.base_bonus
	job.bargain_roll = _random("bargain/" + String(job.job_id)).randf()
	district.home_deliveries.append(job)
	return job

static func _finish_visit(visit: CustomerVisit) -> void:
	var body: E_DistrictNpc = DistrictPopulationService.body_for(visit.customer_id)
	var active: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent if body != null else null
	if active != null and active.visit_id == visit.visit_id:
		NpcServiceRole.finish_appearance(body, visit)
	else:
		var cycle: C_DayCycle = DayPhaseService.current()
		CustomerFlowService.finish(visit, cycle.day_index)

static func _random(seed_text: String) -> RandomNumberGenerator:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_text.hash()
	return generator
#endregion
