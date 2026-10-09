extends "res://tests/gut/test_package_receipts_loss.gd"
## Примечания, курсор, известные жалобы и явно опубликованные сведения доставки в реальном UI.

const SAVE_PATH: String = "user://gut_terminal_notes.pvzh"

var _panel: TerminalPanel = null

#region Окружение терминала
## Освобождает UI перед World и удаляет только собственный тестовый слот.
func after_each() -> void:
	if is_instance_valid(_panel):
		_panel.free()
	super.after_each()
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _open_details() -> UI_TerminalPackageDetailInfo:
	PackageHistoryService.record_arrival(_parcel(), 1)
	_panel = (load("res://content/ui/terminal_panel.tscn") as PackedScene).instantiate() as TerminalPanel
	add_child(_panel)
	_panel._refresh(true)
	return _panel.get_node("%PackageDetailInfo") as UI_TerminalPackageDetailInfo


func _note_field(detail: UI_TerminalPackageDetailInfo) -> TextEdit:
	return detail.get_node("MarginContainer/VBoxContainer/TextEdit") as TextEdit
#endregion

#region Постоянные заметки и ввод
## Реальный ввод сохраняется по history_id; немедленный refresh не переписывает текст, курсор и выделение.
func test_typing_survives_immediate_refresh_with_caret_selection_and_undo() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var editor: TextEdit = _note_field(detail)
	editor.insert_text_at_caret("первая строка\nвторая строка")
	editor.set_caret_line(1)
	editor.set_caret_column(4)
	editor.select(0, 1, 0, 6)
	var caret_before_refresh: Vector2i = Vector2i(editor.get_caret_line(), editor.get_caret_column())
	_panel._refresh(true)
	assert_eq(_ledger.records[0].note, "первая строка\nвторая строка")
	assert_eq(editor.text, _ledger.records[0].note)
	assert_eq(editor.get_caret_line(), caret_before_refresh.x)
	assert_eq(editor.get_caret_column(), caret_before_refresh.y)
	assert_true(editor.has_selection())
	assert_eq(editor.get_selected_text(), "ервая")
	assert_true(editor.has_undo())


## Переиспользованный номер выдачи не смешивает текст или положение курсора разных историй.
func test_switching_reused_number_keeps_notes_and_restores_previous_history_caret() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var first: PackageRegistrationRecord = _ledger.records[0]
	var editor: TextEdit = _note_field(detail)
	editor.insert_text_at_caret("первое примечание")
	editor.set_caret_column(6)
	var parcel: Entity = PackageQueries.find_live_package("receipt")
	PackageRegistrationService.register_package(parcel)
	(parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState.Registration.DELIVERED
	assert_true(PackageRegistrationService.release_number(parcel))
	var second_parcel: Entity = _parcel("second")
	var second: PackageRegistrationRecord = PackageHistoryService.record_arrival(second_parcel, 1)
	PackageRegistrationService.register_package(second_parcel)
	assert_eq(first.number, second.number)
	assert_ne(first.history_id, second.history_id)
	_panel._on_package_selected("second")
	assert_eq(first.note, "первое примечание")
	assert_eq(editor.text, "")
	editor.insert_text_at_caret("второе примечание")
	_panel._on_package_selected("receipt")
	assert_eq(second.note, "второе примечание")
	assert_eq(editor.text, "первое примечание")
	assert_eq(editor.get_caret_column(), 6)
	assert_false(PackageHistoryService.update_note("", "не должно сохраниться"))
	assert_false(PackageHistoryService.update_note("неизвестная история", "не должно сохраниться"))
	assert_eq(first.note, "первое примечание")


## Закрытие и повторное открытие того же UI сохраняют незавершённый ввод и курсор.
func test_end_editing_and_reopen_keep_unfinished_note() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var editor: TextEdit = _note_field(detail)
	editor.insert_text_at_caret("ещё пишу...")
	editor.set_caret_column(4)
	detail.end_editing()
	detail.clear_info()
	_panel._refresh(true)
	assert_eq(_ledger.records[0].note, "ещё пишу...")
	assert_eq(editor.text, "ещё пишу...")
	assert_eq(editor.get_caret_column(), 4)


## Записанный слот восстанавливает примечание отсутствующей коробки и текст жалобы после пересоздания UI.
func test_notes_and_complaint_survive_slot_write_read_and_ui_recreation() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var editor: TextEdit = _note_field(detail)
	editor.insert_text_at_caret("[img]это обычное примечание[/img]\nне трогать")
	detail.end_editing()
	_visit.definition = _visit.definition.duplicate() as DEF_Customer
	_visit.definition.complaint_text = "Где посылка, бездельник? [b]Текст[/b]"
	assert_true(CustomerVisitLifecycle.create_complaint(_visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true))
	# Авторское определение остаётся каноническим; уже поданный текст сохранён в самой жалобе.
	_visit.definition = (load("res://content/domains/customers/definitions/def_customer_schedule_default.tres") as DEF_CustomerSchedule).events[0].customer
	_world.remove_entity(PackageQueries.find_live_package("receipt"))
	var data: Dictionary = {
		"ledger": SaveDataCodec.component_data(_ledger),
		"flow": SaveDataCodec.component_data(_flow),
	}
	assert_eq(AutosaveStore.write(data, SAVE_PATH), OK)
	var restored: Dictionary = AutosaveStore.read(SAVE_PATH)
	_ledger.records.clear()
	_flow.visits.clear()
	assert_true(SaveDataCodec.apply_fields(_ledger, (restored.ledger as Dictionary).fields as Dictionary))
	assert_true(SaveDataCodec.apply_fields(_flow, (restored.flow as Dictionary).fields as Dictionary))
	_panel.free()
	_panel = (load("res://content/ui/terminal_panel.tscn") as PackedScene).instantiate() as TerminalPanel
	add_child(_panel)
	_panel._refresh(true)
	detail = _panel.get_node("%PackageDetailInfo") as UI_TerminalPackageDetailInfo
	assert_eq(_note_field(detail).text, "[img]это обычное примечание[/img]\nне трогать")
	assert_eq(_flow.visits[0].complaint.message, "Где посылка, бездельник? [b]Текст[/b]")
	assert_null(PackageQueries.find_live_package("receipt"))


## Выход открытого терминала из SceneTree сохраняет ввод и не освобождает уже отключённый GUI-фокус.
func test_open_panel_can_exit_tree_with_unfinished_note() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	_panel.visible = true
	var editor: TextEdit = _note_field(detail)
	editor.grab_focus()
	editor.insert_text_at_caret("сохранить при выходе")
	remove_child(_panel)
	assert_false(_panel.is_inside_tree())
	assert_eq(_ledger.records[0].note, "сохранить при выходе")
	assert_false(_panel.visible)


## Изменение сведений жалобы учитывается подписью и обновляет UI без принудительного refresh.
func test_complaint_resolution_refreshes_without_erasing_note_or_caret() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var editor: TextEdit = _note_field(detail)
	editor.insert_text_at_caret("жду решения")
	editor.set_caret_column(2)
	assert_true(CustomerVisitLifecycle.create_complaint(_visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true))
	_panel._refresh()
	var description: RichTextLabel = detail.get_node("%RichTextLabelDescription") as RichTextLabel
	assert_true("Штраф по жалобе ещё не назначен" in description.text)
	CustomerOutcomeService.resolve_complaint(_visit, _wallet, 2)
	_panel._refresh()
	assert_true("Статус жалобы: подтверждена" in description.text)
	assert_true("Штраф по жалобе: 200" in description.text)
	assert_eq(editor.text, "жду решения")
	assert_eq(editor.get_caret_column(), 2)
#endregion

#region Известные и скрытые сведения
## Авторский текст, имя, причина, статус и реальный штраф показываются буквально, включая BBCode и резкую реплику.
func test_complaint_shows_saved_author_text_name_reason_status_and_real_fine_as_plain_text() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	_visit.definition = _visit.definition.duplicate() as DEF_Customer
	_visit.definition.complaint_text = "Ты потерял мою посылку, бездельник! [url=secret]ответь[/url]"
	assert_true(CustomerOutcomeService.create_complaint(_visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true, "Старое имя"))
	_visit.definition.display_name = "Новое имя"
	_visit.definition.complaint_text = "Другой текст"
	assert_true(CustomerOutcomeService.create_complaint(_visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true, "Новое имя"))
	CustomerOutcomeService.resolve_complaint(_visit, _wallet, 2)
	var description: RichTextLabel = detail.get_node("%RichTextLabelDescription") as RichTextLabel
	description.bbcode_enabled = true
	_panel._refresh(true)
	assert_true("Жалоба от Старое имя" in description.get_parsed_text())
	assert_true("Не получил посылку" in description.get_parsed_text())
	assert_true("[url=secret]ответь[/url]" in description.get_parsed_text())
	assert_true("бездельник" in description.get_parsed_text())
	assert_true("Штраф по жалобе: 200" in description.get_parsed_text())
	assert_false("Другой текст" in description.get_parsed_text())
	assert_eq(_wallet.operations.size(), 1)


## Уже оплаченная потеря отображается отдельно от жалобы, которая не создала второго штрафа.
func test_manual_loss_fee_remains_visible_when_complaint_is_already_settled() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	_panel._show_archive = true
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(CustomerVisitLifecycle.create_complaint(_visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true))
	CustomerOutcomeService.resolve_complaint(_visit, _wallet, 2)
	_panel._refresh(true)
	var description: String = (detail.get_node("%RichTextLabelDescription") as RichTextLabel).get_parsed_text()
	assert_true("Штраф: 120 · Причина: Заявленная потеря" in description)
	assert_true("Статус жалобы: расчёт уже выполнен" in description)
	assert_true("Штраф по жалобе: 0" in description)
	assert_eq(_wallet.operations.size(), 1)


## Подтверждённое повреждение с нулевой санкцией не превращается в выдуманный штраф.
func test_damaged_complaint_displays_zero_fine_and_hides_unreported_physical_truth() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var parcel: Entity = PackageQueries.find_live_package("receipt")
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	state.damage = C_PackageState.Damage.DESTROYED
	state.opening = C_PackageState.Opening.OPENED
	_visit.package_damaged = true
	assert_true(CustomerVisitLifecycle.create_complaint(_visit, 1, CustomerComplaint.Reason.DAMAGED, true))
	CustomerOutcomeService.resolve_complaint(_visit, _wallet, 2)
	_panel._refresh(true)
	var description: String = (detail.get_node("%RichTextLabelDescription") as RichTextLabel).get_parsed_text()
	assert_true("Повреждённая посылка" in description)
	assert_true("Штраф по жалобе: 0" in description)
	assert_false("уничтожена" in description)
	assert_false("вскрыта" in description)
	assert_true(_wallet.operations.is_empty())


## Отсутствующие данные каталога не скрывают известную жалобу постоянной истории.
func test_missing_catalog_metadata_keeps_known_complaint_visible() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	_ledger.records[0].definition = null
	assert_true(CustomerVisitLifecycle.create_complaint(_visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true))
	_panel._refresh(true)
	var description: String = (detail.get_node("%RichTextLabelDescription") as RichTextLabel).get_parsed_text()
	assert_true("Данные посылки недоступны" in description)
	assert_true("Жалоба от " in description)
	assert_true("Причина жалобы: Не получил посылку" in description)
	assert_true(_visit.complaint.message in description)


## Только опубликованный DTO раскрывает адрес, оплату и утренний срок; частный остаётся скрытым.
func test_delivery_details_require_explicit_publication() -> void:
	var detail: UI_TerminalPackageDetailInfo = _open_details()
	var delivery: TerminalDeliveryInfo = TerminalDeliveryInfo.new()
	delivery.address = "Секретный тупик, дом 4"
	delivery.bonus = 123
	delivery.deadline_day = 9
	detail.present(_ledger.records[0], null, _visit, false, delivery)
	var description: RichTextLabel = detail.get_node("%RichTextLabelDescription") as RichTextLabel
	assert_false("Секретный тупик" in description.text)
	assert_false("Доплата за доставку" in description.text)
	delivery.published = true
	detail.present(_ledger.records[0], null, _visit, false, delivery)
	assert_true("Доставка: Секретный тупик, дом 4" in description.text)
	assert_true("Доплата за доставку: 123" in description.text)
	assert_true("до утра дня 9" in description.text)
	detail.present(_ledger.records[0], null, _visit)
	assert_false("Секретный тупик" in description.text)
#endregion
