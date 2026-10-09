## Показывает выбранную запись регистрации, описание коробки и доступный результат жалобы.
extends PanelContainer
class_name UI_TerminalPackageDetailInfo

## Запрос изменения примечания по постоянному ID истории, без изменения игрового состояния в UI.
signal note_changed(history_id: String, text: String)

@onready var _icon_preview: TextureRect = %TextureIconPreview
@onready var _label_package_id: Label = %LabelID
@onready var _label_package_uid: Label = %LabelUID
@onready var _label_package_name: Label = %LabelName
@onready var _contaner_images: Control = %HBoxContainerImages
@onready var _rich_label_description: RichTextLabel = %RichTextLabelDescription
@onready var _line_edit_ps: TextEdit = $MarginContainer/VBoxContainer/TextEdit

var _history_id: String = ""
var _syncing_note: bool = false
var _reported_note: String = ""
var _note_carets: Dictionary[String, Vector2i] = {}
var _note_scrolls: Dictionary[String, Vector2] = {}

#region Выбранная запись
func _ready() -> void:
	_line_edit_ps.editable = false
	_line_edit_ps.text_changed.connect(_on_note_text_changed)


## Показывает описание и регистрацию; debug_status добавляет фактическое состояние коробки.
func present(
	record: PackageRegistrationRecord,
	state: C_PackageState,
	visit: CustomerVisit,
	debug_status: bool = false,
	delivery: TerminalDeliveryInfo = null,
) -> void:
	visible = true
	_present_note(record)
	# Авторские обращения и пользовательская разметка всегда остаются обычным текстом.
	_rich_label_description.bbcode_enabled = false
	_label_package_id.text = UI_TerminalButtonPackage.number_text(record)
	_label_package_uid.text = record.history_id if not record.history_id.is_empty() else "—"

	var definition: DEF_Package = record.definition
	var lines: PackedStringArray = []
	if definition == null:
		_label_package_name.text = record.package_id
		lines.append("Данные посылки недоступны.")
	else:
		_label_package_name.text = (
			definition.description
			if not definition.description.is_empty()
			else String(definition.key)
		)
		if not definition.comment.is_empty():
			lines.append(definition.comment)
		lines.append("Вес: %.1f кг" % definition.mass_kg)
		lines.append("Учётная стоимость: %d" % definition.accounting_value)
	if record.received_day > 0:
		lines.append("Дата поступления: день %d" % record.received_day)
	lines.append(
		"Дата регистрации: день %d" % record.day_index
		if record.number > 0
		else "Ещё не зарегистрирована. Номер выдачи не назначен."
	)
	lines.append("Отметка: %s" % UI_TerminalButtonPackage.status_text(record, state, visit, debug_status))
	if visit != null and visit.registration_overdue_day > 0:
		lines.append("Пропущен срок регистрации: день %d" % visit.registration_overdue_day)
		if visit.registration_penalty_committed:
			lines.append("Штраф за просрочку регистрации: %d" % -visit.registration_money_delta)
	if debug_status and state != null:
		lines.append("Состояние: %s" % _condition_text(state))
	if visit != null and visit.settlement_committed and visit.money_delta < 0:
		var reason: String = "Расчёт по посылке"
		if visit.declaration == CustomerVisit.Declaration.LOST:
			reason = "Заявленная потеря"
		elif visit.declaration == CustomerVisit.Declaration.REFUSED:
			reason = "Отказ в выдаче"
		lines.append("Штраф: %d · Причина: %s" % [-visit.money_delta, reason])
	lines.append_array(_complaint_lines(visit))
	lines.append_array(_delivery_lines(delivery))
	_rich_label_description.text = "\n".join(lines)


## Очищает поля выбора без изменения записи или состояния коробки.
func clear_info() -> void:
	end_editing()
	_history_id = ""
	_syncing_note = true
	_line_edit_ps.text = ""
	_reported_note = ""
	_line_edit_ps.editable = false
	_syncing_note = false
	_label_package_id.text = "—"
	_label_package_uid.text = "—"
	_label_package_name.text = "Посылка не выбрана"
	_rich_label_description.text = ""


#endregion

#region Примечание и положение ввода
## Проверяет текстовый фокус, чтобы клавиша взаимодействия не закрывала терминал во время ввода.
func is_editing_note() -> bool:
	return _line_edit_ps.has_focus()


## Запоминает курсор и прокрутку текущей истории, затем освобождает текстовый фокус.
func end_editing() -> void:
	_flush_note()
	_remember_note_position()
	if _line_edit_ps.is_inside_tree():
		_line_edit_ps.release_focus()


func _present_note(record: PackageRegistrationRecord) -> void:
	_flush_note()
	var changed_record: bool = _history_id != record.history_id
	if not changed_record and _line_edit_ps.text == record.note:
		return
	_remember_note_position()
	_history_id = record.history_id
	_syncing_note = true
	_line_edit_ps.text = record.note
	_reported_note = record.note
	_line_edit_ps.editable = not _history_id.is_empty()
	_syncing_note = false
	var caret: Vector2i = _note_carets.get(_history_id, Vector2i.ZERO)
	_line_edit_ps.set_caret_line(clampi(caret.x, 0, _line_edit_ps.get_line_count() - 1))
	_line_edit_ps.set_caret_column(caret.y)
	var scroll: Vector2 = _note_scrolls.get(_history_id, Vector2.ZERO)
	_line_edit_ps.scroll_vertical = scroll.y
	_line_edit_ps.scroll_horizontal = int(scroll.x)


func _remember_note_position() -> void:
	if not _history_id.is_empty():
		_note_carets[_history_id] = Vector2i(_line_edit_ps.get_caret_line(), _line_edit_ps.get_caret_column())
		_note_scrolls[_history_id] = Vector2(_line_edit_ps.scroll_horizontal, _line_edit_ps.scroll_vertical)


func _on_note_text_changed() -> void:
	_flush_note()


func _flush_note() -> void:
	if _syncing_note or _history_id.is_empty() or _line_edit_ps.text == _reported_note:
		return
	# Смена выбора и закрытие сохраняют ввод даже до отложенного text_changed.
	_reported_note = _line_edit_ps.text
	note_changed.emit(_history_id, _reported_note)
#endregion

#region Форматирование состояния и жалобы
static func _complaint_lines(visit: CustomerVisit) -> PackedStringArray:
	if visit == null or visit.complaint == null:
		return []
	var complaint: CustomerComplaint = visit.complaint
	var claimant: String = complaint.customer_name if not complaint.customer_name.is_empty() else CustomerPresentation.customer_name(visit)
	var reason: String = "Не получил посылку" if complaint.reason == CustomerComplaint.Reason.NOT_DELIVERED else "Повреждённая посылка"
	var lines: PackedStringArray = [
		"Жалоба от %s · день %d" % [claimant, complaint.created_day],
		"Причина жалобы: %s" % reason,
	]
	if not complaint.message.is_empty():
		lines.append("Обращение: " + complaint.message)
	lines.append("Статус жалобы: " + _complaint_text(complaint))
	if complaint.outcome == CustomerComplaint.Outcome.PENDING:
		lines.append("Штраф по жалобе ещё не назначен.")
	else:
		lines.append("Штраф по жалобе: %d" % maxi(0, -complaint.money_delta))
	return lines


static func _delivery_lines(delivery: TerminalDeliveryInfo) -> PackedStringArray:
	if delivery == null or not delivery.published:
		return []
	if delivery.address.is_empty() or delivery.bonus < 0 or delivery.deadline_day < 1:
		return []
	var lines: PackedStringArray = [
		"Доставка: " + delivery.address,
		"Доплата за доставку: %d" % delivery.bonus,
		"Срок доставки: до утра дня %d" % delivery.deadline_day,
	]
	if not delivery.status_text.is_empty():
		lines.append("Статус доставки: " + delivery.status_text)
	if not delivery.job_id.is_empty() and delivery.status == NpcHomeDelivery.Status.OFFERED and not delivery.can_respond:
		lines.append("Предложение сейчас недоступно. Получатель и зарегистрированная посылка должны быть доступны; срок — до сна.")
	return lines


static func _condition_text(state: C_PackageState) -> String:
	var parts: PackedStringArray = []
	match state.damage:
		C_PackageState.Damage.UNDAMAGED:
			parts.append("целая")
		C_PackageState.Damage.DAMAGED:
			parts.append("повреждена")
		C_PackageState.Damage.DESTROYED:
			parts.append("уничтожена")
	parts.append("вскрыта" if state.opening == C_PackageState.Opening.OPENED else "закрыта")
	if state.leaking:
		parts.append("протекает")
	return " · ".join(parts)


static func _complaint_text(complaint: CustomerComplaint) -> String:
	match complaint.outcome:
		CustomerComplaint.Outcome.PENDING:
			return "на рассмотрении"

		CustomerComplaint.Outcome.CONFIRMED:
			return "подтверждена"

		CustomerComplaint.Outcome.FALSE_CLAIM:
			return "ложная"

		CustomerComplaint.Outcome.WAIVED_PLAYER_DEFEAT:
			return "штраф отменён"

		CustomerComplaint.Outcome.ALREADY_SETTLED:
			return "расчёт уже выполнен"

		CustomerComplaint.Outcome.NO_LIVING_CLAIMANT:
			return "заявитель отсутствует"
	return "—"

#endregion
