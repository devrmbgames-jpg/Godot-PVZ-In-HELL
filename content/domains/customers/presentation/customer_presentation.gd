extends RefCounted
## Форматирует посылку, сохраняя постоянные имена жителей и регистрационные номера.
class_name CustomerPresentation


#region World sign projection
## Supplies only derived text to the actor-owned sign; no role/outcome transition occurs.
static func project_sign(request: NpcSignTextRequest, body: E_DistrictNpc) -> void:
	var visit: CustomerVisit = CustomerFlowQueries.visit_for(body)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	if visit != null and not visit.finished and agent.phase in [
		C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.DIALOGUE,
		C_CustomerAgent.Phase.WAITING_FOR_PACKAGE,
	]:
		request.intent_id = visit.visit_id
		var number: int = registered_number(visit)
		request.text = (
			String(TranslationServer.translate("ЗАКАЗ №%03d\nУПАКОВКУ НЕ ВСКРЫВАТЬ.")) % number
			if number >= 0
			else String(TranslationServer.translate("НОМЕРА НЕТ.\nПРОСКАНИРУЙТЕ ПОСЫЛКИ."))
		)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null or cycle.phase not in [C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		return
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var job: NpcHomeDelivery = HomeDeliveryQueries.personal_for(
		identity.npc_id,
		visit.visit_id if visit != null else &"",
	)
	if job != null:
		request.intent_id = (
			StringName("%s|%s" % [request.intent_id, job.job_id])
			if not request.intent_id.is_empty() else job.job_id
		)
		var delivery: String = String(TranslationServer.translate("ДОСТАВИТЬ ДОМОЙ. +%d\n%s"))
		if not request.text.is_empty():
			request.text += "\n"
		request.text += delivery % [
			job.bonus,
			NpcPopulationQueries.place_name(job.address_id),
		]
#endregion


#region Представление получателя и заказа
## Читает имя постоянной личности, иначе использует правила старого визита.
static func customer_name(visit: CustomerVisit) -> String:
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(visit.customer_id) if visit != null else null
	)
	return (
		person.display_name
		if person != null
		else visit.definition.display_name
		if visit != null and visit.definition != null
		else "Клиент"
	)


## Показывает постоянного получателя и настоящий номер или его собственную загадку.
static func request_text(visit: CustomerVisit) -> String:
	var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
	if (
		person != null and person.rule_for(DEF_NpcTrait.Kind.RIDDLE) != null
		and not visit.riddle_solved
	):
		return "%s · Номер узнаешь, когда ответишь на мою загадку." % customer_name(visit)

	var number: int = registered_number(visit)
	if number >= 0:
		return (
			"%s\nМой заказ №%03d. Передайте коробку мне или положите её на стойку выдачи."
			% [customer_name(visit), number]
		)
	return (
		"%s\nМой заказ ещё не зарегистрирован. Просканируйте поступившие коробки."
		% customer_name(visit)
	)


## Загадочник раскрывает номер только после решения загадки в диалоге.
static func uses_quick_visit(visit: CustomerVisit) -> bool:
	var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
	if person != null:
		if person.profile.presentation_cues.has("npc/angel/sign_dialogue"):
			return true
		return (
			visit.definition != null
			and visit.definition.introduction == DEF_Customer.Introduction.ANNOUNCE_ORDER
			and person.rule_for(DEF_NpcTrait.Kind.RIDDLE) == null
			and person.rule_for(DEF_NpcTrait.Kind.PROVOCATEUR) == null
		)
	return uses_quick_order(visit.definition)


## Сохраняет авторское знакомство в сценах без районной сессии.
static func uses_quick_order(definition: DEF_Customer) -> bool:
	return (
		definition != null and definition.introduction == DEF_Customer.Introduction.ANNOUNCE_ORDER
		and definition.dialogue_mode == DEF_Customer.DialogueMode.DIRECT
		and not uses_wall_order(definition)
	)


## Читает действующую регистрацию, не создавая новый номер.
static func registered_number(visit: CustomerVisit) -> int:
	if visit == null:
		return -1

	var ledger: C_PackageLedger = PackageQueries.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			if record.package_id == visit.package_id and record.active and record.number > 0:
				return record.number
	return -1


## Распознаёт старое испытание взглядом вне районного населения.
static func uses_wall_order(definition: DEF_Customer) -> bool:
	if definition == null or definition.challenge == null:
		return false

	var condition: DEF_GazeChallengeCondition = (
		definition.challenge.condition as DEF_GazeChallengeCondition
	)
	return (
		condition != null and not condition.required_attention
		and definition.challenge.trigger == DEF_Challenge.Trigger.ON_ARRIVAL
	)


## Объясняет результат авторитетной проверки физической коробки.
static func check_text(delivery_status: PackageDeliveryCheck.Result) -> String:
	match delivery_status:
		PackageDeliveryCheck.Result.MISSING:
			return "Положите коробку на стойку."
		PackageDeliveryCheck.Result.MULTIPLE:
			return "Оставьте на стойке только одну коробку."
		PackageDeliveryCheck.Result.UNREGISTERED:
			return "Сначала зарегистрируйте эту посылку сканером."
		PackageDeliveryCheck.Result.WRONG_PACKAGE:
			return "Это чужая посылка."
		PackageDeliveryCheck.Result.UNASSIGNED:
			return "Посылка не назначена этому клиенту."
		PackageDeliveryCheck.Result.DESTROYED:
			return "Посылка уничтожена. Оформите исход в терминале."
		PackageDeliveryCheck.Result.HELD:
			return "Отпустите коробку на стойку."
		_:
			return "Выдача уже закрыта."


## Форматирует результат визита и его финансовый журнал.
static func visit_text(visit: CustomerVisit) -> String:
	var actual: Array[String] = ["Не выдана", "Выдана", "Клиент отказался", "Отказ игрока"]
	var declared: Array[String] = ["Не отмечено", "Забрал", "Отказался", "Потеряна"]
	var visit_summary: String = (
		"%s · факт: %s · отметка: %s\nУдовлетворённость: %d · расчёт: %+d"
		% [
			visit.package_id,
			actual[visit.actual],
			declared[visit.declaration],
			visit.satisfaction,
			visit.money_delta,
		]
	)
	if visit.complaint != null:
		var outcomes: Array[String] = ([
			"на рассмотрении",
			"подтверждена",
			"ложная",
			"штраф отменён: клиент побеждён игроком",
			"расчёт уже выполнен",
			"клиент мёртв",
		])
		visit_summary += (
			"\nЖалоба: %s · расчёт: %+d"
			% [outcomes[visit.complaint.outcome], visit.complaint.money_delta]
		)
	return visit_summary
#endregion
