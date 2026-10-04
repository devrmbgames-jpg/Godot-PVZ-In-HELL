extends "res://tests/gut/test_district_delivery.gd"
## Опубликованные доставки, реальные кнопки терминала и постоянное чтение известных событий.

var _panel: TerminalPanel = null

#region Окружение
## Освобождает интерфейс до удаления сессии района.
func after_each() -> void:
	if is_instance_valid(_panel):
		_panel.free()
		_panel = null
	super.after_each()

func _terminal_visit() -> CustomerVisit:
	_delivery_case(_district.people[0], "private_minimum")
	return _delivery_case(_district.people[3], "terminal")

func _create_panel() -> void:
	_panel = (load("res://content/ui/terminal_panel.tscn") as PackedScene).instantiate() as TerminalPanel
	add_child(_panel)
	_panel._refresh(true)

func _line(package_id: String) -> UI_TerminalButtonPackage:
	for child: Node in _panel.get_node("%PackageList").get_children():
		var row: UI_TerminalButtonPackage = child as UI_TerminalButtonPackage
		if row.package_id() == package_id:
			return row
	return null

func _delivery(visit: CustomerVisit) -> NpcHomeDelivery:
	for job: NpcHomeDelivery in _district.home_deliveries:
		if job.visit_id == visit.visit_id:
			return job
	return null

func _published(visit: CustomerVisit) -> TerminalDeliveryInfo:
	var visits: Dictionary[String, CustomerVisit] = {visit.package_id: visit}
	return NpcDeliveryOfferService.published_by_package(PackageRegistrationService.ledger(), PackageRegistrationService.live_states(), visits).get(visit.package_id) as TerminalDeliveryInfo

func _description() -> String:
	return (_panel.get_node("%PackageDetailInfo").get_node("%RichTextLabelDescription") as RichTextLabel).text
#endregion

#region Действия опубликованной доставки
## Кнопка принимает ровно одну сохранённую запись; повторный сигнал не выдаёт коробку и деньги.
func test_delivery_button_accepts_one_order_and_repeated_request_is_safe() -> void:
	var visit: CustomerVisit = _terminal_visit()
	var job: NpcHomeDelivery = _delivery(visit)
	_create_panel()
	_panel.open_for(_player)
	_panel._on_package_selected(visit.package_id)
	var button: Button = _line(visit.package_id).get_node("%ButtonDeliveryOK") as Button
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_eq(_district.home_deliveries.size(), 2)
	assert_eq(visit.next_followup_day, 2)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_not_null(CustomerFlowService.parcel_for(visit.package_id))
	assert_eq(WalletService.current().operations.size(), 0)
	_panel._on_delivery_accepted(job.job_id)
	assert_eq(_district.home_deliveries.size(), 2)
	assert_true("Принята" in _description())
	assert_true("до утра дня 2" in _description())
	assert_true(("Доставка: " + DistrictPopulationService.place_name(job.address_id)) in _description())
	assert_false((_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).visible)
	_panel.close_panel()
	_panel.open_for(_player)
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_false((_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).visible)

## Отказ кнопкой сохраняет обычный визит и настоящую коробку.
func test_decline_button_preserves_ordinary_collection() -> void:
	var visit: CustomerVisit = _terminal_visit()
	_create_panel()
	_panel.open_for(_player)
	var job: NpcHomeDelivery = _delivery(visit)
	(_line(visit.package_id).get_node("%ButtonDeloveryCancel") as Button).pressed.emit()
	_panel._on_delivery_declined(job.job_id)
	assert_eq(job.status, NpcHomeDelivery.Status.DECLINED)
	assert_false(visit.finished)
	assert_false(visit.home_delivery_declined)
	assert_eq(visit.next_followup_day, 0)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_not_null(CustomerFlowService.parcel_for(visit.package_id))
	assert_eq(WalletService.current().balance, 0)
	assert_true("Предложение отклонено" in _description())

## Неопубликованные личные договорённости и ID ловушки не поступают в терминальный DTO.
func test_private_promise_and_trap_are_hidden_until_explicit_publication() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "private")
	var job: NpcHomeDelivery = NpcDeliveryOfferService.assign_personal(visit.visit_id, &"secret_trap")
	assert_false(NpcDeliveryOfferService.respond_published(job.job_id, true))
	_create_panel()
	_panel.open_for(_player)
	assert_false((_line(visit.package_id).get_node("%DeliveryControl") as Control).visible)
	assert_false("Доставка:" in _description())
	assert_false("secret_trap" in _description())
	assert_null(_published(visit))
	assert_eq(PackageHistoryService.record_for(visit.package_id).read_event_ids.size(), 0)
	assert_same(NpcDeliveryOfferService.assign_personal(visit.visit_id, &"secret_trap", true), job)
	_panel._refresh()
	assert_true((_line(visit.package_id).get_node("%DeliveryControl") as Control).visible)
	assert_true("Доставка:" in _description())
	assert_false("secret_trap" in _description())
	assert_true(NpcDeliveryOfferService.respond_published(job.job_id, true))

## Исчезновение коробки отключает действия; stale-сигнал не создаёт обещание или LOST.
func test_missing_box_and_night_disable_offer_actions() -> void:
	var visit: CustomerVisit = _terminal_visit()
	var job: NpcHomeDelivery = _delivery(visit)
	_create_panel()
	_panel.open_for(_player)
	DayPhaseService.current().phase = C_DayCycle.Phase.NIGHT
	_panel._refresh()
	assert_true((_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).disabled)
	_panel._on_delivery_accepted(job.job_id)
	assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	_world.remove_entity(parcel)
	parcel.queue_free()
	_panel._refresh()
	assert_true((_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).disabled)
	_panel._on_delivery_accepted(job.job_id)
	assert_eq(job.status, NpcHomeDelivery.Status.OFFERED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_true("сейчас недоступно" in _description())

## Пересборка после сигнала сохраняет фокус на том же заказе.
func test_keyboard_focus_survives_refresh_and_acceptance() -> void:
	var visit: CustomerVisit = _terminal_visit()
	_create_panel()
	_panel.open_for(_player)
	(_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).grab_focus()
	_panel._refresh(true)
	assert_same(get_viewport().gui_get_focus_owner(), _line(visit.package_id).get_node("%Button"))
	(_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).grab_focus()
	(_line(visit.package_id).get_node("%ButtonDeliveryOK") as Button).pressed.emit()
	assert_same(get_viewport().gui_get_focus_owner(), _line(visit.package_id).get_node("%Button"))
#endregion

#region События и чтение
## Открытие подробностей читает только выбранную историю, последующие refresh не возвращают иконку.
func test_detail_read_clears_only_selected_notification() -> void:
	var visit: CustomerVisit = _terminal_visit()
	_create_panel()
	assert_true((_line(visit.package_id).get_node("%TextureAlertIconInfo") as Control).visible)
	_panel._selected_package_id = CustomerFlowService.current().visits[0].package_id
	_panel.open_for(_player)
	assert_true((_line(visit.package_id).get_node("%TextureAlertIconInfo") as Control).visible)
	_panel._on_package_selected(visit.package_id)
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
	assert_eq(record.read_event_ids.size(), 1)
	assert_false((_line(visit.package_id).get_node("%TextureAlertIconInfo") as Control).visible)
	var read_ids: PackedStringArray = record.read_event_ids.duplicate()
	_panel._refresh(true)
	_panel.close_panel()
	_panel.open_for(_player)
	assert_eq(record.read_event_ids, read_ids)
	assert_false((_line(visit.package_id).get_node("%TextureAlertIconInfo") as Control).visible)

## Штраф имеет приоритет над жалобой и предложением; после чтения решение жалобы создаёт новое событие.
func test_notice_priority_and_later_complaint_decision() -> void:
	var visit: CustomerVisit = _terminal_visit()
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
	var info: TerminalDeliveryInfo = _published(visit)
	assert_true(CustomerFlowService.create_complaint(visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true))
	var notice: TerminalPackageNotice = TerminalPackageNoticeService.present(record, visit, info)
	assert_eq(notice.severity, TerminalPackageNotice.Severity.WARNING)
	assert_true(TerminalPackageNoticeService.mark_read(record.history_id, notice.event_ids))
	assert_eq(TerminalPackageNoticeService.present(record, visit, info).severity, TerminalPackageNotice.Severity.NONE)
	var complaint: CustomerComplaint = visit.complaint
	complaint.outcome = CustomerComplaint.Outcome.CONFIRMED
	complaint.resolved_day = 1
	complaint.money_delta = -100
	notice = TerminalPackageNoticeService.present(record, visit, info)
	assert_eq(notice.severity, TerminalPackageNotice.Severity.CRITICAL)
	var line: UI_TerminalButtonPackage = (load("res://content/ui/ui_terminal_package_line.tscn") as PackedScene).instantiate() as UI_TerminalButtonPackage
	add_child_autofree(line)
	line.present(record, null, visit, false, true, false, info, notice)
	assert_true((line.get_node("%TextureAlertIconCrit") as Control).visible)
	assert_false((line.get_node("%TextureAlertIconWar") as Control).visible)
	assert_false((line.get_node("%TextureAlertIconInfo") as Control).visible)
	assert_true(TerminalPackageNoticeService.mark_read(record.history_id, notice.event_ids))
	assert_false(TerminalPackageNoticeService.mark_read(record.history_id, notice.event_ids))
	assert_eq(TerminalPackageNoticeService.present(record, visit, info).severity, TerminalPackageNotice.Severity.NONE)

## Прочитанные события переживают codec и не переходят другой коробке с тем же номером выдачи.
func test_read_events_round_trip_are_bound_to_history_not_number() -> void:
	var visit: CustomerVisit = _terminal_visit()
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
	var notice: TerminalPackageNotice = TerminalPackageNoticeService.present(record, visit, _published(visit))
	assert_true(TerminalPackageNoticeService.mark_read(record.history_id, notice.event_ids))
	var copy: PackageRegistrationRecord = SaveDataCodec.decode(SaveDataCodec.encode(record)) as PackageRegistrationRecord
	assert_not_null(copy)
	assert_eq(copy.read_event_ids, record.read_event_ids)
	assert_eq(TerminalPackageNoticeService.present(copy, visit, _published(visit)).severity, TerminalPackageNotice.Severity.NONE)
	var other: PackageRegistrationRecord = PackageRegistrationRecord.new()
	other.number = copy.number
	other.history_id = "another_history"
	assert_eq(TerminalPackageNoticeService.present(other, visit, _published(visit)).severity, TerminalPackageNotice.Severity.INFO)
	assert_false(TerminalPackageNoticeService.mark_read("unknown", notice.event_ids))

## Принятое обязательство создаёт предупреждение, а исходная непрочитанная заявка — информационную иконку.
func test_delivery_status_change_has_its_own_unread_event() -> void:
	var visit: CustomerVisit = _terminal_visit()
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
	var notice: TerminalPackageNotice = TerminalPackageNoticeService.present(record, visit, _published(visit))
	TerminalPackageNoticeService.mark_read(record.history_id, notice.event_ids)
	assert_true(NpcDeliveryOfferService.respond_published(_delivery(visit).job_id, true))
	notice = TerminalPackageNoticeService.present(record, visit, _published(visit))
	assert_eq(notice.severity, TerminalPackageNotice.Severity.WARNING)
	assert_eq(notice.event_ids.size(), 1)
#endregion
