extends CanvasLayer
## Представление инвентаря: кнопки отправляют сервисные запросы, количество и связи принадлежат игре.
class_name InventoryPanel

const REFRESH_INTERVAL: float = 0.15
const SLOT_SIZE: Vector2 = Vector2(140, 130)
const ICON_SIZE: Vector2 = Vector2(46, 46)
const SLOT_PADDING: int = 8

## Участник, чей инвентарь показывается и чей ввод захватывает панель.
@export var player: Entity = null
var _capture: int = 0
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _refresh_remaining: float = 0.0
var _rows_signature: String = ""
var _target: WeakRef = null
var _status: String = ""
var _selected_id: String = ""
@onready var _root: Control = $Root
@onready var _rows: GridContainer = $Root/Center/Panel/Content/Scroll/Rows
@onready var _condition: Label = $Root/Center/Panel/Content/Condition
@onready var _feedback: Label = $Root/Center/Panel/Content/Feedback
@onready var _close: Button = $Root/Center/Panel/Content/Close
@onready var _details: Label = $Root/Center/Panel/Content/Details
@onready var _use: Button = $Root/Center/Panel/Content/Actions/Use
@onready var _drop: Button = $Root/Center/Panel/Content/Actions/Drop


#region Жизненный цикл и ввод
func _ready() -> void:
	_close.text = "Закрыть"
	_root.hide()
	_close.pressed.connect(close_inventory)
	_use.pressed.connect(_use_selected)
	_drop.pressed.connect(_drop_selected)


func _exit_tree() -> void:
	close_inventory()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		if _capture != 0:
			close_inventory()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()
	elif _capture != 0 and event.is_action_pressed(&"menu"):
		close_inventory()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var icons: Array[Texture2D] = InputPromptService.textures(&"inventory")
	_close.icon = icons[0] if not icons.is_empty() else null
	if _capture == 0:
		return
	if not GrabService.holder_available(player) or player.has_component(C_Death):
		close_inventory()
		return

	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = REFRESH_INTERVAL
		_refresh()


#endregion

#region Открытие и закрытие
## Захватывает модальный ввод и запоминает слабую цель посылки; возвращает успех открытия.
func open_inventory() -> bool:
	if _capture != 0 or not GrabService.holder_available(player) or player.has_component(C_Death) or not player.has_component(C_Inventory) or InteractionControlFocus.current(player) >= InteractionControlFocus.Priority.PUSH:
		return false

	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	var target: Entity = InteractionTargetingService.find_target(player, interactor) if interactor != null else null
	_target = weakref(target) if target != null and target.has_component(C_Package) else null
	_capture = InteractionControlFocus.acquire(player, self, InteractionControlFocus.Priority.MODAL)
	if _capture == 0:
		return false

	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.show()
	_rows_signature = ""
	_status = ""
	_refresh()
	_close.grab_focus()
	return true


## Идемпотентно освобождает захват, цель и режим мыши с учётом других модальных окон.
func close_inventory() -> void:
	if _capture == 0:
		return

	InteractionControlFocus.release(player, _capture)
	_capture = 0
	Input.mouse_mode = _previous_mouse if not is_instance_valid(player) or InteractionControlFocus.current(player) < InteractionControlFocus.Priority.MODAL else Input.MOUSE_MODE_VISIBLE
	_target = null
	if is_instance_valid(_root):
		_root.hide()


#endregion

#region Производное представление
func _package_target() -> Entity:
	var target: Entity = _target.get_ref() as Entity if _target != null else null
	if not EntityAvailability.contains(target, ECS.world):
		return null

	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	return target if interactor != null and InteractionTargetingService.find_target(player, interactor) == target else null


func _refresh() -> void:
	var owned: Array[Entity] = InventoryService.items(player)
	var inventory: C_Inventory = player.get_component(C_Inventory) as C_Inventory
	_condition.text = "Стеков %d / %d\nВыберите предмет. Для плёнки наведитесь на посылку перед открытием." % [owned.size(), inventory.maximum_stacks]
	_feedback.text = _status
	var target: Entity = _package_target()
	var selected: Entity = InventoryService.item_by_id(player, _selected_id)
	if selected == null and not owned.is_empty():
		selected = owned[0]
	_selected_id = selected.id if selected != null else ""

	var reason: String = InventoryService.use_reason(player, selected, target) if selected != null else "Выберите предмет"
	_use.disabled = not reason.is_empty()
	_drop.disabled = selected == null or not InventoryDropService.drop_reason(player, selected).is_empty()
	_details.text = "%s\n%s" % [(selected.get_component(C_InventoryItem) as C_InventoryItem).definition.display_name, "Можно использовать" if reason.is_empty() else reason] if selected != null else "Пусто. Подберите небольшой расходник кнопкой E."
	_use.tooltip_text = reason
	_drop.tooltip_text = InventoryDropService.drop_reason(player, selected) if selected != null else "Выберите предмет"
	var signature: String = "%d:%s;" % [inventory.maximum_stacks, _selected_id]
	for item: Entity in owned:
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		signature += "%s:%d;" % [item.id, state.quantity]
	if signature == _rows_signature and _rows.get_child_count() > 0:
		return

	_rows_signature = signature
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for index: int in maxi(inventory.maximum_stacks, owned.size()):
		_add_slot(owned[index] if index < owned.size() else null, index)


func _add_slot(item: Entity, index: int) -> void:
	var button: Button = Button.new()
	button.name = "Slot%d" % index
	button.custom_minimum_size = SLOT_SIZE
	button.toggle_mode = true
	button.disabled = item == null
	button.button_pressed = item != null and item.id == _selected_id
	_rows.add_child(button)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, SLOT_PADDING)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var caption: Label = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	if item == null:
		caption.text = "Пусто"
		return

	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	icon.texture = state.definition.icon
	caption.text = "%s\n×%d" % [state.definition.display_name, state.quantity]
	button.tooltip_text = "%s ×%d" % [state.definition.display_name, state.quantity]
	button.pressed.connect(_select_item.bind(item.id))


#endregion

#region Выбор и сервисные запросы
func _select_item(item_id: String) -> void:
	_selected_id = item_id
	_refresh()
	for slot: Node in _rows.get_children():
		var button: Button = slot as Button
		if button != null and button.button_pressed:
			button.grab_focus()
			break


func _use_selected() -> void:
	_use_item(_selected_id)


func _drop_selected() -> void:
	if not _can_submit():
		return

	var item: Entity = InventoryService.item_by_id(player, _selected_id)
	_status = "Весь стек выложен на землю" if InventoryDropService.drop(player, item) else "Не удалось выложить стек. Нужно свободное место на полу рядом."
	_refresh()


func _can_submit() -> bool:
	return _capture != 0 and GrabService.holder_available(player) and InteractionControlFocus.current(player, _capture) < InteractionControlFocus.Priority.MODAL


func _use_item(item_id: String) -> void:
	if not _can_submit():
		return

	var item: Entity = InventoryService.item_by_id(player, item_id)
	var reason: String = InventoryService.use_reason(player, item, _package_target())
	if reason.is_empty():
		_status = "Применено" if InventoryService.use(player, item, _package_target()) else "Эффект не применён; предмет сохранён"
	else:
		_status = reason
	_refresh()

#endregion
