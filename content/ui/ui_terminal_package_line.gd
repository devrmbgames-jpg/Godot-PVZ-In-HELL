## Строка посылки в терминале: показывает запись и отправляет запросы заявления владельцу интерфейса.
extends PanelContainer
class_name UI_TerminalButtonPackage

## Запрос выбора записи с этим package_id.
signal package_selected(package_id: String)
## Запрос заявления TAKEN в журнале; физическую выдачу не подтверждает.
signal taken_requested(package_id: String)
## Запрос заявления REFUSED в журнале.
signal refused_requested(package_id: String)
## Запрос заявления LOST в журнале.
signal lost_requested(package_id: String)
## Запрос принятия конкретного опубликованного предложения доставки.
signal delivery_accepted(job_id: StringName)
## Запрос отказа от допуслуги; обычное получение посылки сохраняется.
signal delivery_declined(job_id: StringName)

@onready var _button_body: Button = %Button
@onready var _icon_preview_package: TextureRect = %TexturePreviewPackage
@onready var _label_number_info: Label = %LabelNumber
@onready var _label_status_info: Label = %LabelStatus
@onready var _button_ok: Button = %ButtonOK
@onready var _button_cancel: Button = %ButtonCancel
@onready var _button_lost: Button = %ButtonLost
@onready var _icons_statuses_container: Control = %IconsStatusesType
@onready var _icon_status_explotion: Control = %IconExplotion
@onready var _icon_status_toxic: Control = %IconToxic
@onready var _icon_status_psico: Control = %IconPsico
@onready var _icon_status_fire: Control = %IconFire
@onready var _icon_status_weight: Control = %IconWeight
@onready var _icon_status_anomaly: Control = %IconAnomaly
@onready var _icon_status_light: Control = %IconLight
@onready var _icon_status_fragile: Control = %IconFragile
@onready var _icon_status_fluid: Control = %IconFluid
@onready var _label_price: Label = %LabelPrice
@onready var _label_description_short: Label = %LabelDescriptionShort

## Непрочитанное предложение или обновление доставки.
@onready var _alert_info:     Control = %TextureAlertIconInfo
## Непрочитанная жалоба или обязательство.
@onready var _alert_warrning: Control = %TextureAlertIconWar
## Непрочитанная подтверждённая санкция.
@onready var _alert_critical: Control = %TextureAlertIconCrit

## Авторский раздел опубликованной доставки.
@onready var _control_delivery: Control = %DeliveryControl
## Запрос принятия допуслуги.
@onready var _button_delivery_ok: Button = %ButtonDeliveryOK
## Запрос отказа от допуслуги.
@onready var _button_delivery_cancel: Button = %ButtonDeloveryCancel
@onready var _label_delivery_bonus: Label = get_node("%DeliveryControl/Label2") as Label


var _package_id: String = ""
var _delivery_job_id: StringName = &""


#region Заполнение строки
func _ready() -> void:
	_button_body.toggled.connect(_on_body_toggled)
	_button_ok.pressed.connect(_on_taken_pressed)
	_button_cancel.pressed.connect(_on_refused_pressed)
	_button_lost.pressed.connect(_on_lost_pressed)
	_button_delivery_ok.pressed.connect(_on_delivery_accepted)
	_button_delivery_cancel.pressed.connect(_on_delivery_declined)
	_control_delivery.visible = false
	for icon: Control in [_alert_info, _alert_warrning, _alert_critical]:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Показывает запись; actions_enabled управляет заявлениями, debug_status раскрывает фактическое состояние.
func present(
	record: PackageRegistrationRecord,
	state: C_PackageState,
	visit: CustomerVisit,
	selected: bool,
	actions_enabled: bool = true,
	debug_status: bool = false,
	delivery: TerminalDeliveryInfo = null,
	notice: TerminalPackageNotice = null,
) -> void:
	_package_id = record.package_id
	_button_body.set_pressed_no_signal(selected)
	_label_number_info.text = number_text(record)
	_label_status_info.text = status_text(record, state, visit, debug_status)

	var definition: DEF_Package = record.definition
	if definition == null:
		_label_price.text = "—"
		_label_description_short.text = record.package_id
		_set_status_icons(null)
	else:
		_label_price.text = str(definition.accounting_value)
		_label_description_short.text = (
			definition.description
			if not definition.description.is_empty()
			else String(definition.key)
		)
		_set_status_icons(definition)

	var can_declare: bool = (
		actions_enabled
		and visit != null
		and visit.started
		and visit.declaration == CustomerVisit.Declaration.NONE
	)
	_button_ok.disabled = not can_declare
	_button_cancel.disabled = not can_declare
	_button_lost.disabled = not (
		actions_enabled and visit != null and visit.declaration == CustomerVisit.Declaration.NONE
	)
	_present_delivery(delivery, actions_enabled)
	_present_notice(notice)


## Возвращает постоянный ID записи, показанной этой строкой.
func package_id() -> String:
	return _package_id


## Возвращает клавиатурный фокус строке после пересборки или решения о доставке.
func focus_row() -> void:
	_button_body.grab_focus()


func _present_delivery(delivery: TerminalDeliveryInfo, actions_enabled: bool) -> void:
	_control_delivery.visible = delivery != null and delivery.published
	_delivery_job_id = delivery.job_id if _control_delivery.visible else &""
	_button_body.tooltip_text = ""
	if not _control_delivery.visible:
		return
	_label_delivery_bonus.text = "+%d" % delivery.bonus
	_control_delivery.tooltip_text = "%s\n%s · +%d$ · до утра дня %d" % [delivery.status_text, delivery.address, delivery.bonus, delivery.deadline_day]
	_button_body.tooltip_text = _control_delivery.tooltip_text
	var offered: bool = delivery.status == NpcHomeDelivery.Status.OFFERED
	_button_delivery_ok.visible = offered
	_button_delivery_cancel.visible = offered
	_button_delivery_ok.disabled = not actions_enabled or not delivery.can_respond
	_button_delivery_cancel.disabled = _button_delivery_ok.disabled
	_button_delivery_ok.tooltip_text = "Принять доставку за +%d$ до утра дня %d" % [delivery.bonus, delivery.deadline_day]
	_button_delivery_cancel.tooltip_text = "Отказаться от доставки. Покупатель получит посылку обычным способом."


func _present_notice(notice: TerminalPackageNotice) -> void:
	var severity: TerminalPackageNotice.Severity = notice.severity if notice != null else TerminalPackageNotice.Severity.NONE
	_alert_info.visible = severity == TerminalPackageNotice.Severity.INFO
	_alert_warrning.visible = severity == TerminalPackageNotice.Severity.WARNING
	_alert_critical.visible = severity == TerminalPackageNotice.Severity.CRITICAL
	if notice != null and not notice.text.is_empty():
		_button_body.tooltip_text += ("\n" if not _button_body.tooltip_text.is_empty() else "") + notice.text


## Форматирует заявление игрока; фактическую выдачу и состояние раскрывает только debug_status.
static func status_text(
	record: PackageRegistrationRecord,
	state: C_PackageState,
	visit: CustomerVisit,
	debug_status: bool = false,
) -> String:
	if visit != null:
		match visit.declaration:
			CustomerVisit.Declaration.TAKEN:
				return "ЗАБРАЛИ"

			CustomerVisit.Declaration.REFUSED:
				return "ОТКАЗАЛИСЬ"

			CustomerVisit.Declaration.LOST:
				return "ПОТЕРЯНА"
	if record.number == 0:
		if visit != null and visit.registration_overdue_day > 0:
			return "ПРОСРОЧЕНА РЕГИСТРАЦИЯ"
		if not debug_status:
			return "НЕ ЗАРЕГИСТРИРОВАНА"
	if not debug_status:
		return "БЕЗ ОТМЕТКИ"
	if visit != null:
		if visit.actual == CustomerVisit.Actual.DELIVERED:
			return "ВЫДАНА · НЕ ОТМЕЧЕНА"
		if visit.actual == CustomerVisit.Actual.CUSTOMER_REFUSED:
			return "КЛИЕНТ ОТКАЗАЛСЯ"

	if not record.active:
		match record.departure:
			C_PackageState.Registration.DELIVERED:
				return "ВЫДАНА"

			C_PackageState.Registration.RETURNED:
				return "ВОЗВРАЩЕНА"

			C_PackageState.Registration.BOUGHT_OUT:
				return "ПРИСВОЕНА"

	if state == null:
		return "НЕТ В ПВЗ"

	var parts: PackedStringArray = ["ОЖИДАЕТ"]
	if state.damage == C_PackageState.Damage.DAMAGED:
		parts.append("ПОВРЕЖДЕНА")
	elif state.damage == C_PackageState.Damage.DESTROYED:
		parts.append("УНИЧТОЖЕНА")
	if state.opening == C_PackageState.Opening.OPENED:
		parts.append("ВСКРЫТА")
	return " · ".join(parts)


## Не выдаёт внутренний нулевой номер за номер заказа получателя.
static func number_text(record: PackageRegistrationRecord) -> String:
	return "№%03d" % record.number if record.number > 0 else "Без номера"


#endregion

#region Иконки и запросы действий
func _set_status_icons(definition: DEF_Package) -> void:
	var has_definition: bool = definition != null
	var hazard_class: DEF_Package.HazardClass = (
		definition.history_hazard_class
		if has_definition
		else DEF_Package.HazardClass.NORMAL
	)
	var tags: int = definition.tags if has_definition else 0
	_icon_status_explotion.visible = has_definition and hazard_class == DEF_Package.HazardClass.EXPLOSIVE
	_icon_status_toxic.visible = has_definition and hazard_class == DEF_Package.HazardClass.TOXIC
	_icon_status_psico.visible = false
	_icon_status_fire.visible = false

	_icon_status_weight.visible = has_definition and bool(tags & DEF_Package.Tag.HEAVY)
	_icon_status_anomaly.visible = (
		has_definition
		and (
			hazard_class == DEF_Package.HazardClass.OTHER
			or definition.hazard_on_damaged != null
			or definition.hazard_on_destroyed != null
		)
	)

	_icon_status_light.visible = false
	_icon_status_fragile.visible = (
		has_definition
		and (
			bool(tags & DEF_Package.Tag.FRAGILE)
			or hazard_class == DEF_Package.HazardClass.FRAGILE
		)
	)

	_icon_status_fluid.visible = (
		has_definition
		and (
			bool(tags & DEF_Package.Tag.LIQUID)
			or hazard_class == DEF_Package.HazardClass.LIQUID
		)
	)

	_icons_statuses_container.visible = (
		_icon_status_explotion.visible
		or _icon_status_toxic.visible
		or _icon_status_weight.visible
		or _icon_status_anomaly.visible
		or _icon_status_fragile.visible
		or _icon_status_fluid.visible
	)


func _on_body_toggled(toggled_on: bool) -> void:
	if toggled_on and not _package_id.is_empty():
		package_selected.emit(_package_id)


func _on_taken_pressed() -> void:
	if not _package_id.is_empty():
		taken_requested.emit(_package_id)


func _on_refused_pressed() -> void:
	if not _package_id.is_empty():
		refused_requested.emit(_package_id)


func _on_lost_pressed() -> void:
	if not _package_id.is_empty():
		lost_requested.emit(_package_id)


func _on_delivery_accepted() -> void:
	if _control_delivery.visible and not _button_delivery_ok.disabled and not _delivery_job_id.is_empty():
		delivery_accepted.emit(_delivery_job_id)


func _on_delivery_declined() -> void:
	if _control_delivery.visible and not _button_delivery_cancel.disabled and not _delivery_job_id.is_empty():
		delivery_declined.emit(_delivery_job_id)

#endregion
