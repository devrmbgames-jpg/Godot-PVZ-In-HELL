extends RefCounted
class_name CustomerPresentation


static func request_text(visit: CustomerVisit) -> String:
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger != null:
		for record: PackageRegistrationRecord in ledger.records:
			if record.package_id == visit.package_id and record.active:
				return "%s\nМой заказ №%03d. Положите его на стойку выдачи." % [visit.definition.display_name, record.number]
	return "%s\nМой заказ ещё не зарегистрирован. Просканируйте поступившие коробки." % visit.definition.display_name


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
