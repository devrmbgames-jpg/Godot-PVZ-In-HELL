extends RefCounted
class_name CustomerPresentation


static func request_text(visit: CustomerVisit) -> String:
	var number: int = registered_number(visit)
	if number >= 0:
		return "%s\nМой заказ №%03d. Передайте коробку мне или положите её на стойку выдачи." % [visit.definition.display_name, number]
	return "%s\nМой заказ ещё не зарегистрирован. Просканируйте поступившие коробки." % visit.definition.display_name


static func registered_number(visit: CustomerVisit) -> int:
	if visit == null:
		return -1
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			if record.package_id == visit.package_id and record.active:
				return record.number
	return -1


static func uses_wall_order(definition: DEF_Customer) -> bool:
	if definition == null or definition.challenge == null:
		return false
	var condition: DEF_GazeChallengeCondition = definition.challenge.condition as DEF_GazeChallengeCondition
	return condition != null and not condition.required_attention and definition.challenge.trigger == DEF_Challenge.Trigger.ON_ARRIVAL


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


static func visit_text(visit: CustomerVisit) -> String:
	var actual: Array[String] = ["Не выдана", "Выдана", "Клиент отказался", "Отказ игрока"]
	var declared: Array[String] = ["Не отмечено", "Забрал", "Отказался", "Потеряна"]
	var result: String = "%s · факт: %s · отметка: %s\nУдовлетворённость: %d · расчёт: %+d" % [visit.package_id, actual[visit.actual], declared[visit.declaration], visit.satisfaction, visit.money_delta]
	if visit.complaint != null:
		var outcomes: Array[String] = ["на рассмотрении", "подтверждена", "ложная", "штраф отменён: клиент побеждён игроком", "расчёт уже выполнен", "клиент мёртв"]
		result += "\nЖалоба: %s · расчёт: %+d" % [outcomes[visit.complaint.outcome], visit.complaint.money_delta]
	return result
