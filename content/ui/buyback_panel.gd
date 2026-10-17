extends CanvasLayer
## Native подтверждение показывает quote; только commerce service продаёт вещи и платит.
class_name BuybackPanel

const REFRESH_SECONDS: float = 0.2
var _actor: WeakRef
var _trader: WeakRef
var _offer: BuybackQuote
var _capture: int = 0
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _refresh_remaining: float = 0.0
var _last_click_frame: int = -1

@onready var _dialog: ConfirmationDialog = $Confirmation
@onready var _summary: Label = $Confirmation/Contents/Summary
@onready var _items: RichTextLabel = $Confirmation/Contents/Scroll/Items


#region Modal lifetime
func _ready() -> void:
	_dialog.confirmed.connect(_confirm)
	_dialog.canceled.connect(close_panel)
	_dialog.close_requested.connect(close_panel)


func _exit_tree() -> void:
	_release()


func _input(event: InputEvent) -> void:
	if _capture != 0 and event.is_action_pressed(&"menu"):
		close_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _capture == 0:
		return
	_refresh_remaining -= delta
	if _refresh_remaining > 0.0:
		return
	_refresh_remaining = REFRESH_SECONDS
	var actor: Entity = _actor.get_ref() as Entity
	var trader: Entity = _trader.get_ref() as Entity
	if (
		not GrabQueries.holder_available(actor) or actor.has_component(C_Death)
		or not GrabQueries.holder_available(trader) or trader.has_component(C_Death)
	):
		close_panel()
		return
	var container: E_BuybackContainer = BuybackQueries.container_for(trader)
	if (
		container == null or container.get_component(C_Buyback) != _offer.state
		or not BuybackQueries
		.unavailable_reason(_offer.state, trader, DayPhaseQueries.current())
		.is_empty()
	):
		close_panel()


## Открывает одно предложение и захватывает штатный модальный ввод.
func open_for(actor: Entity, trader: Entity) -> bool:
	if (
		_capture != 0
		or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.MODAL
	):
		return false
	_offer = BuybackTradeService.quote(actor, trader)
	if not _offer.reason.is_empty():
		return false
	_actor = weakref(actor)
	_trader = weakref(trader)
	_capture = InteractionControlFocus.acquire(actor, self, InteractionControlFocus.Priority.MODAL)
	if _capture == 0:
		return false
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_present()
	_dialog.popup_centered_clamped(Vector2i(700, 480), 0.9)
	_dialog.get_cancel_button().grab_focus()
	return true


## Закрытие и Cancel освобождают только собственный focus token; предметы остаются на месте.
func close_panel() -> void:
	_release()
	queue_free()


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
#endregion


#region Read-only quote and explicit confirmation
func _present(message: String = "") -> void:
	_summary.text = "%s\nИтого: %d. %s" % [
		_offer.state.profile.display_name,
		_offer.amount,
		message,
	]
	var lines: PackedStringArray = _offer.market_lines.duplicate()
	for line: BuybackSaleItem in _offer.items:
		lines.append(
			"%s ×%d · обычных %d · спрос ×%d · сумма %d"
			% [
				line.definition.display_name,
				line.quantity,
				line.quantity - line.premium_quantity,
				line.premium_quantity,
				line.amount,
			]
		)
	if not _offer.rejected.is_empty():
		lines.append("\nОстанутся в контейнере:")
		lines.append_array(_offer.rejected)
	if _offer.items.is_empty() and _offer.rejected.is_empty():
		lines.append("Положите свободные вещи целиком внутрь контейнера.")
	_items.text = "\n".join(lines)
	_dialog.get_ok_button().disabled = _offer.amount <= 0 or not _offer.reason.is_empty()


func _confirm() -> void:
	if _capture == 0 or _last_click_frame == Engine.get_process_frames():
		return
	_last_click_frame = Engine.get_process_frames()
	var actor: Entity = _actor.get_ref() as Entity
	var trader: Entity = _trader.get_ref() as Entity
	var status: BuybackTradeService.Status = BuybackTradeService.confirm(actor, trader, _offer)
	if status in [BuybackTradeService.Status.COMMITTED, BuybackTradeService.Status.DUPLICATE]:
		close_panel()
	elif status == BuybackTradeService.Status.CHANGED:
		_offer = BuybackTradeService.quote(actor, trader)
		if not _offer.reason.is_empty():
			close_panel()
			return
		_present("Состав или цена изменились. Проверьте новое предложение и подтвердите снова.")
		_dialog.get_cancel_button().grab_focus()
	else:
		_present("Расчёт отклонён. Закройте окно и попробуйте снова.")
		_dialog.get_ok_button().disabled = true
#endregion
