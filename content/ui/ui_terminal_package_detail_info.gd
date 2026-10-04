## Показывает выбранную запись регистрации, описание коробки и доступный результат жалобы.
extends PanelContainer
class_name UI_TerminalPackageDetailInfo

@onready var _icon_preview: TextureRect = %TextureIconPreview
@onready var _label_package_id: Label = %LabelID
@onready var _label_package_uid: Label = %LabelUID
@onready var _label_package_name: Label = %LabelName
@onready var _contaner_images: Control = %HBoxContainerImages
@onready var _rich_label_description: RichTextLabel = %RichTextLabelDescription


#region Выбранная запись
## Показывает описание и регистрацию; debug_status добавляет фактическое состояние коробки.
func present(
	record: PackageRegistrationRecord,
	state: C_PackageState,
	visit: CustomerVisit,
	debug_status: bool = false,
) -> void:
	visible = true
	_label_package_id.text = "№%03d" % record.number
	_label_package_uid.text = record.history_id if not record.history_id.is_empty() else "—"

	var definition: DEF_Package = record.definition
	if definition == null:
		_label_package_name.text = record.package_id
		_rich_label_description.text = "Данные посылки недоступны."
		return

	_label_package_name.text = (
		definition.description
		if not definition.description.is_empty()
		else String(definition.key)
	)

	var lines: PackedStringArray = []
	if not definition.comment.is_empty():
		lines.append(definition.comment)
	lines.append("Вес: %.1f кг" % definition.mass_kg)
	lines.append("Учётная стоимость: %d" % definition.accounting_value)
	lines.append("Дата регистрации: день %d" % record.day_index)
	lines.append("Отметка: %s" % UI_TerminalButtonPackage.status_text(record, state, visit, debug_status))
	if debug_status and state != null:
		lines.append("Состояние: %s" % _condition_text(state))
	if visit != null and visit.complaint != null:
		lines.append("Жалоба: %s" % _complaint_text(visit.complaint))
	_rich_label_description.text = "\n".join(lines)


## Очищает поля выбора без изменения записи или состояния коробки.
func clear_info() -> void:
	_label_package_id.text = "—"
	_label_package_uid.text = "—"
	_label_package_name.text = "Посылка не выбрана"
	_rich_label_description.text = ""


#endregion

#region Форматирование состояния и жалобы
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
