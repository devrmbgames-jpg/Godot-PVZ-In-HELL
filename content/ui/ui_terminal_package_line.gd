# Кнопка посылки с краткой информацией и тремя terminal outcome-действиями.
extends PanelContainer
class_name UI_TerminalButtonPackage

signal package_selected(package_id: String)
signal taken_requested(package_id: String)
signal refused_requested(package_id: String)
signal lost_requested(package_id: String)

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

var _package_id: String = ""


func _ready() -> void:
	_button_body.toggled.connect(_on_body_toggled)
	_button_ok.pressed.connect(_on_taken_pressed)
	_button_cancel.pressed.connect(_on_refused_pressed)
	_button_lost.pressed.connect(_on_lost_pressed)


func present(
	record: PackageRegistrationRecord,
	state: C_PackageState,
	visit: CustomerVisit,
	selected: bool,
	actions_enabled: bool = true,
	debug_status: bool = false,
) -> void:
	_package_id = record.package_id
	_button_body.set_pressed_no_signal(selected)
	_label_number_info.text = "№%03d" % record.number
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
	_button_lost.disabled = not can_declare


func package_id() -> String:
	return _package_id


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
