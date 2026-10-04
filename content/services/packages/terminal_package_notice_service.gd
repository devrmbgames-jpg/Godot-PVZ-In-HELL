extends RefCounted
## Выделяет известные события терминала и сохраняет их чтение по истории посылки.
class_name TerminalPackageNoticeService

#region Известные события
## Готовит один приоритет уведомления; частные сведения доставки не используются.
static func present(record: PackageRegistrationRecord, visit: CustomerVisit, delivery: TerminalDeliveryInfo = null) -> TerminalPackageNotice:
	var notice: TerminalPackageNotice = TerminalPackageNotice.new()
	if visit != null:
		if visit.registration_penalty_committed and visit.registration_money_delta < 0:
			_add(record, notice, "late/%s/%d" % [visit.visit_id, visit.registration_penalty_day], TerminalPackageNotice.Severity.CRITICAL, "Назначен штраф за просрочку регистрации: %d$" % -visit.registration_money_delta)
		if visit.settlement_committed and visit.money_delta < 0:
			_add(record, notice, "settlement/%s/%d/%d" % [visit.visit_id, visit.settlement_day, visit.declaration], TerminalPackageNotice.Severity.CRITICAL, "Назначен штраф по посылке: %d$" % -visit.money_delta)
		var complaint: CustomerComplaint = visit.complaint
		if complaint != null:
			var event_id: String = "complaint/%s/%d/%d" % [complaint.complaint_id, complaint.outcome, complaint.resolved_day]
			_add(record, notice, event_id, TerminalPackageNotice.Severity.WARNING, "Обновление жалобы покупателя")
			if complaint.outcome == CustomerComplaint.Outcome.CONFIRMED and complaint.money_delta < 0:
				_add(record, notice, "sanction/" + event_id, TerminalPackageNotice.Severity.CRITICAL, "Подтверждён штраф по жалобе: %d$" % -complaint.money_delta)
	if delivery != null and delivery.published and not delivery.job_id.is_empty():
		var severity: TerminalPackageNotice.Severity = TerminalPackageNotice.Severity.INFO
		if delivery.status in [NpcHomeDelivery.Status.ACCEPTED, NpcHomeDelivery.Status.FAILED]:
			severity = TerminalPackageNotice.Severity.WARNING
		_add(record, notice, "delivery/%s/%d" % [delivery.job_id, delivery.status], severity, delivery.status_text)
	return notice
#endregion

#region Постоянное чтение
## Записывает ключи показанных событий один раз; номер выдачи не служит ключом истории.
static func mark_read(history_id: String, event_ids: PackedStringArray) -> bool:
	var registry: C_PackageLedger = PackageRegistrationService.ledger()
	if registry == null or history_id.is_empty():
		return false
	for record: PackageRegistrationRecord in registry.records:
		if record.history_id != history_id:
			continue
		var changed: bool = false
		for event_id: String in event_ids:
			if not event_id.is_empty() and not record.read_event_ids.has(event_id):
				record.read_event_ids.append(event_id)
				changed = true
		return changed
	return false

static func _add(record: PackageRegistrationRecord, notice: TerminalPackageNotice, event_id: String, severity: TerminalPackageNotice.Severity, text: String) -> void:
	notice.event_ids.append(event_id)
	if record.read_event_ids.has(event_id):
		return
	if severity > notice.severity:
		notice.severity = severity
	if not notice.text.is_empty():
		notice.text += "\n"
	notice.text += text
#endregion
