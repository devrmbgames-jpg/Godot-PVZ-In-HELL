extends RefCounted
## Parcel presentation with permanent district names and unchanged order numbering.
class_name CustomerPresentation

#region Customer presentation
## Resolves a permanent person name, falling back to legacy case policy.
static func customer_name(visit: CustomerVisit) -> String:
	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id) if visit != null else null
	return person.display_name if person != null else visit.definition.display_name if visit != null and visit.definition != null else "Клиент"


## Presents the permanent recipient and real registration number or intrinsic riddle.
static func request_text(visit: CustomerVisit) -> String:
	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
	if person != null and person.profile.rule_for(DEF_NpcTrait.Kind.RIDDLE) != null and not visit.riddle_solved:
		return "%s · Номер узнаешь, когда ответишь на мою загадку." % customer_name(visit)
	var number: int = registered_number(visit)
	if number >= 0:
		return "%s\nМой заказ №%03d. Передайте коробку мне или положите её на стойку выдачи." % [customer_name(visit), number]
	return "%s\nМой заказ ещё не зарегистрирован. Просканируйте поступившие коробки." % customer_name(visit)


## Intrinsic riddles keep their number behind the existing dialogue solution.
static func uses_quick_visit(visit: CustomerVisit) -> bool:
	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
	if person != null:
		return visit.definition != null and visit.definition.introduction == DEF_Customer.Introduction.ANNOUNCE_ORDER and person.profile.rule_for(DEF_NpcTrait.Kind.RIDDLE) == null and person.profile.rule_for(DEF_NpcTrait.Kind.PROVOCATEUR) == null
	return uses_quick_order(visit.definition)


## Preserves authored introduction rules in scenes without a district.
static func uses_quick_order(definition: DEF_Customer) -> bool:
	return (
		definition != null and definition.introduction == DEF_Customer.Introduction.ANNOUNCE_ORDER
		and definition.dialogue_mode == DEF_Customer.DialogueMode.DIRECT
		and not uses_wall_order(definition)
	)


## Looks up the existing active registration without inventing another number.
static func registered_number(visit: CustomerVisit) -> int:
	if visit == null:
		return -1
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			if record.package_id == visit.package_id and record.active:
				return record.number
	return -1


## Recognizes the legacy gaze challenge outside the district population.
static func uses_wall_order(definition: DEF_Customer) -> bool:
	if definition == null or definition.challenge == null:
		return false
	var condition: DEF_GazeChallengeCondition = definition.challenge.condition as DEF_GazeChallengeCondition
	return condition != null and not condition.required_attention and definition.challenge.trigger == DEF_Challenge.Trigger.ON_ARRIVAL


## Explains the authoritative physical parcel check.
static func check_text(result: PackageDeliveryCheck.Result) -> String:
	match result:
		PackageDeliveryCheck.Result.MISSING: return "Положите коробку на стойку."
		PackageDeliveryCheck.Result.MULTIPLE: return "Оставьте на стойке только одну коробку."
		PackageDeliveryCheck.Result.UNREGISTERED: return "Сначала зарегистрируйте эту посылку сканером."
		PackageDeliveryCheck.Result.WRONG_PACKAGE: return "Это чужая посылка."
		PackageDeliveryCheck.Result.UNASSIGNED: return "Посылка не назначена этому клиенту."
		PackageDeliveryCheck.Result.DESTROYED: return "Посылка уничтожена. Оформите исход в терминале."
		PackageDeliveryCheck.Result.HELD: return "Отпустите коробку на стойку."
		_: return "Выдача уже закрыта."


## Displays the case outcome and its existing financial journal.
static func visit_text(visit: CustomerVisit) -> String:
	var actual: Array[String] = ["Не выдана", "Выдана", "Клиент отказался", "Отказ игрока"]
	var declared: Array[String] = ["Не отмечено", "Забрал", "Отказался", "Потеряна"]
	var result: String = "%s · факт: %s · отметка: %s\nУдовлетворённость: %d · расчёт: %+d" % [visit.package_id, actual[visit.actual], declared[visit.declaration], visit.satisfaction, visit.money_delta]
	if visit.complaint != null:
		var outcomes: Array[String] = ["на рассмотрении", "подтверждена", "ложная", "штраф отменён: клиент побеждён игроком", "расчёт уже выполнен", "клиент мёртв"]
		result += "\nЖалоба: %s · расчёт: %+d" % [outcomes[visit.complaint.outcome], visit.complaint.money_delta]
	return result
#endregion
