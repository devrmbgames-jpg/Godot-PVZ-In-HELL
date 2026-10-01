extends CanvasLayer
## Derived inventory view. Buttons submit gameplay effects; the UI owns no quantities or relationships.
class_name InventoryPanel

const REFRESH_INTERVAL: float = 0.15

@export var player: Entity = null
var _capture: int = 0
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _refresh_remaining: float = 0.0
var _rows_signature: String = ""
var _target: WeakRef = null
var _status: String = ""
@onready var _root: Control = $Root
@onready var _rows: VBoxContainer = $Root/Center/Panel/Content/Scroll/Rows
@onready var _condition: Label = $Root/Center/Panel/Content/Condition
@onready var _feedback: Label = $Root/Center/Panel/Content/Feedback
@onready var _close: Button = $Root/Center/Panel/Content/Close


func _ready() -> void:
	_root.hide()
	_close.pressed.connect(close_inventory)


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
	if _capture == 0:
		return
	if not GrabService.holder_available(player) or player.has_component(C_Death):
		close_inventory()
		return
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = REFRESH_INTERVAL
		_refresh()


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


func close_inventory() -> void:
	if _capture == 0:
		return
	InteractionControlFocus.release(player, _capture)
	_capture = 0
	Input.mouse_mode = _previous_mouse if not is_instance_valid(player) or InteractionControlFocus.current(player) < InteractionControlFocus.Priority.MODAL else Input.MOUSE_MODE_VISIBLE
	_target = null
	if is_instance_valid(_root):
		_root.hide()


func _package_target() -> Entity:
	var target: Entity = _target.get_ref() as Entity if _target != null else null
	if not EntityAvailability.contains(target, ECS.world):
		return null
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	return target if interactor != null and InteractionTargetingService.find_target(player, interactor) == target else null


func _refresh() -> void:
	var owned: Array[Entity] = InventoryService.items(player)
	var inventory: C_Inventory = player.get_component(C_Inventory) as C_Inventory
	_condition.text = "Стеков %d / %d · [Tab / Esc] Закрыть\nЗадача: используйте еду при голоде, аптечку при ранениях. Для плёнки наведитесь на посылку перед открытием." % [owned.size(), inventory.maximum_stacks]
	_feedback.text = _status
	var target: Entity = _package_target()
	var signature: String = ""
	for item: Entity in owned:
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		signature += "%s:%d:%s;" % [item.id, state.quantity, InventoryService.use_reason(player, item, target)]
	if signature == _rows_signature and _rows.get_child_count() > 0:
		return
	_rows_signature = signature
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	if owned.is_empty():
		var empty: Label = Label.new()
		empty.text = "Пусто. Подберите небольшой расходник кнопкой E."
		_rows.add_child(empty)
	for item: Entity in owned:
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		var reason: String = InventoryService.use_reason(player, item, target)
		var button: Button = Button.new()
		button.text = "%s ×%d · %s" % [state.definition.display_name, state.quantity, "Использовать" if reason.is_empty() else reason]
		button.disabled = not reason.is_empty()
		button.pressed.connect(_use_item.bind(item.id))
		_rows.add_child(button)


func _use_item(item_id: String) -> void:
	if _capture == 0 or not GrabService.holder_available(player) or InteractionControlFocus.current(player, _capture) >= InteractionControlFocus.Priority.MODAL:
		return
	var item: Entity = InventoryService.item_by_id(player, item_id)
	var reason: String = InventoryService.use_reason(player, item, _package_target())
	if reason.is_empty():
		_status = "Применено" if InventoryService.use(player, item, _package_target()) else "Эффект не применён; предмет сохранён"
	else:
		_status = reason
	_refresh()
