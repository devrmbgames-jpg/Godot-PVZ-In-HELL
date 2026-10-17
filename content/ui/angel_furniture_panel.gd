extends CanvasLayer
## Собственная native панель Ангела: проекция его истории и явное подтверждение покупки.
class_name AngelFurniturePanel

const REFRESH_SECONDS: float = 0.25
var _actor: WeakRef
var _state: C_AngelOrders
var _offer: AngelFurnitureQuote
var _capture: int = 0
var _previous_mouse: Input.MouseMode
var _remaining: float = 0.0

@onready var _terminal: E_Terminal = get_parent() as E_Terminal
@onready var _window: Window = $Shop
@onready var _status: Label = $Shop/Contents/Status
@onready var _catalog: VBoxContainer = $Shop/Contents/CatalogScroll/Catalog
@onready var _history: RichTextLabel = $Shop/Contents/History
@onready var _confirmation: ConfirmationDialog = $Confirmation


#region Native modal lifetime
func _ready() -> void:
	_terminal.panel_open_requested.connect(open_for)
	_terminal.panel_close_requested.connect(close_panel)
	_terminal.panel_state_requested.connect(_report_state)
	_window.close_requested.connect(close_panel)
	_window.window_input.connect(_window_input)
	$Shop/Contents/Close.pressed.connect(close_panel)
	_confirmation.confirmed.connect(_confirm)
	_confirmation.canceled.connect(_cancel_offer)
	_confirmation.close_requested.connect(_cancel_offer)


func _exit_tree() -> void:
	_release()


func _input(event: InputEvent) -> void:
	if _capture != 0 and event.is_action_pressed(&"menu"):
		close_panel()
		get_viewport().set_input_as_handled()


func _window_input(event: InputEvent) -> void:
	if _capture != 0 and event.is_action_pressed(&"menu"):
		close_panel()
		_window.set_input_as_handled()


func _cancel_offer() -> void:
	_offer = null


func _process(delta: float) -> void:
	if _capture == 0:
		return
	_remaining -= delta
	if _remaining > 0.0:
		return
	_remaining = REFRESH_SECONDS
	if (
		not AngelFurnitureService.available(_terminal, _actor.get_ref() as Entity)
		or _terminal.get_component(C_AngelOrders) != _state
	):
		close_panel()
		return
	_present_history()


## Открытие не оплачивает и не требует работающего терминала ПВЗ/живого NPC.
func open_for(actor: Entity) -> void:
	if _capture != 0 or not AngelFurnitureService.available(_terminal, actor):
		return
	_actor = weakref(actor)
	_state = _terminal.get_component(C_AngelOrders) as C_AngelOrders
	_capture = InteractionControlFocus.acquire(actor, self, InteractionControlFocus.Priority.MODAL)
	if _capture == 0:
		return
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_present_catalog()
	_present_history()
	_window.popup_centered_clamped(Vector2i(720, 570), 0.9)
	$Shop/Contents/Close.grab_focus()


## Закрывает только свой native UI и token, оплаченные обещания остаются у Component.
func close_panel() -> void:
	_confirmation.hide()
	_window.hide()
	_offer = null
	_release()


func _release() -> void:
	if _capture == 0:
		return
	var actor: Entity = _actor.get_ref() as Entity
	InteractionControlFocus.release(actor, _capture)
	_capture = 0
	Input.mouse_mode = (
		_previous_mouse
		if not is_instance_valid(actor)
		or InteractionControlFocus.current(actor) < InteractionControlFocus.Priority.MODAL
		else Input.MOUSE_MODE_VISIBLE
	)


func _report_state(query: TerminalPanelStateQuery) -> void:
	query.record_open(_capture != 0, _actor.get_ref() as Entity if _actor != null else null)
#endregion


#region Проекция каталога и собственной истории
func _present_catalog() -> void:
	for child: Node in _catalog.get_children():
		child.free()
	var day: int = DayPhaseQueries.current().day_index + 1
	for item: DEF_InventoryItem in _state.profile.catalog:
		if item == null:
			continue
		var button: Button = Button.new()
		button.text = "%s ×1 · %d" % [item.display_name, item.market_price]
		button.tooltip_text = "Утро дня %d · %s" % [day, _state.profile.receiving_hint]
		button.pressed.connect(_choose.bind(item))
		_catalog.add_child(button)


func _present_history() -> void:
	_status.text = "Баланс: %d. Новые заказы: утро дня %d · %s" % [
		WalletService.current().balance,
		DayPhaseQueries.current().day_index + 1,
		_state.profile.receiving_hint,
	]
	var receiving: C_OrderReceiving = _terminal.get_component(C_OrderReceiving) as C_OrderReceiving
	var lines: PackedStringArray = []
	for record: AngelFurnitureOrder in _state.orders:
		var stage: String = "ожидает утра"
		if record.received:
			stage = "получен"
		elif record.issued:
			stage = "выдан на площадку"
		elif record.ready_day <= DayPhaseQueries.current().day_index:
			stage = "освободите место" if receiving.blocked else "готов к выдаче"
		lines.append(
			"%s ×1 · оплачено %d · утро %d · %s · %s"
			% [
				record.item.display_name,
				record.total_price,
				record.ready_day,
				record.receiving_hint,
				stage,
			]
		)
	_history.text = "\n".join(lines) if not lines.is_empty() else "Оплаченных заказов пока нет."


func _choose(item: DEF_InventoryItem) -> void:
	_offer = AngelFurnitureService.quote(_actor.get_ref() as Entity, _terminal, item)
	if not _offer.reason.is_empty():
		_status.text = _offer.reason
		return
	var record: AngelFurnitureOrder = _offer.order
	_confirmation.dialog_text = "%s ×1\nПолная цена: %d\nУтро дня %d\n%s" % [
		record.item.display_name,
		record.total_price,
		record.ready_day,
		record.receiving_hint,
	]
	_confirmation.popup_centered_clamped(Vector2i(540, 260), 0.9)
	_confirmation.get_cancel_button().grab_focus()


func _confirm() -> void:
	if _capture == 0 or _offer == null:
		return
	var result: AngelFurnitureService.Status = AngelFurnitureService.confirm(
		_actor.get_ref() as Entity,
		_offer,
	)
	_offer = null
	_present_catalog()
	_present_history()
	if result not in [
		AngelFurnitureService.Status.COMMITTED,
		AngelFurnitureService.Status.DUPLICATE,
	]:
		_status.text = "Заказ не оплачен. Проверьте цену, баланс и площадку; выберите товар заново."
#endregion
