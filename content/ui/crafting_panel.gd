extends CanvasLayer
## Подтверждение всего содержимого; native UI показывает факты и посылает явную передачу.
class_name CraftingPanel

const REFRESH_SECONDS: float = 0.2
var _actor: WeakRef
var _container: WeakRef
var _offer: CraftingQuote
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
	var container: E_CraftingContainer = _container.get_ref() as E_CraftingContainer
	if (
		not CraftingQueries.available_reason(container, actor).is_empty()
		or container.get_component(C_Crafting) != _offer.state
	):
		close_panel()


## Открывает наблюдаемое предложение без резерва/расхода и захватывает только свой focus.
func open_for(actor: Entity, container: E_CraftingContainer) -> bool:
	_offer = CraftingService.quote(actor, container)
	if not _offer.reason.is_empty() or _capture != 0:
		return false
	_actor = weakref(actor)
	_container = weakref(container)
	_capture = InteractionControlFocus.acquire(actor, self, InteractionControlFocus.Priority.MODAL)
	if _capture == 0:
		return false
	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_present(false)
	_dialog.popup_centered_clamped(Vector2i(700, 480), 0.9)
	_dialog.get_cancel_button().grab_focus()
	return true


## Отмена освобождает только собственный modal token и ничего не передаёт.
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


#region Явное подтверждение
func _confirm() -> void:
	if _capture == 0 or _last_click_frame == Engine.get_process_frames():
		return
	_last_click_frame = Engine.get_process_frames()
	var actor: Entity = _actor.get_ref() as Entity
	var status: CraftingService.Status = CraftingService.confirm(actor, _offer)
	if status in [CraftingService.Status.COMMITTED, CraftingService.Status.DUPLICATE]:
		close_panel()
	elif status == CraftingService.Status.CHANGED:
		_offer = CraftingService.quote(actor, _container.get_ref() as E_CraftingContainer)
		_present(true)
	else:
		_summary.text = "Сейчас набор нельзя передать. Заберите предметы или попробуйте позже."
		_dialog.get_ok_button().disabled = true


func _present(changed: bool) -> void:
	var prefix: String = "Состав изменился. Проверьте новый набор.\n" if changed else ""
	_summary.text = prefix + (
		"Весь набор будет передан без оплаты. Результат — следующим утром. "
		+ "Неиспользованное — подарок; неудачный набор будет израсходован."
	)
	if not _offer.reason.is_empty():
		_summary.text += "\n" + _offer.reason
	var lines: PackedStringArray = []
	for item: CraftingInput in _offer.inputs:
		lines.append("%s ×%d" % [item.definition.display_name, item.quantity])
	_items.text = "\n".join(lines)
	_dialog.get_ok_button().disabled = not _offer.reason.is_empty() or _offer.inputs.is_empty()
#endregion
