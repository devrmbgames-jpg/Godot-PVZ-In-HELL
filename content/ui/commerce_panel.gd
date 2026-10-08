extends CanvasLayer
## Торговый интерфейс: запрашивает покупки и задания через сервисы, освобождает модальный ввод.
class_name CommercePanel

const PANEL_SIZE: Vector2 = Vector2(720, 450)
const MARGIN: float = 32.0
const REFRESH_SECONDS: float = 0.2
const RESULT_TEXT: Array[String] = ["Готово", "Уже выполнено", "Действие недоступно", "Запрос конфликтует", "Недостаточно денег", "Инвентарь заполнен", "Сейчас недоступно", "Освободите место в зоне выдачи мебели"]

var _actor: Entity = null
var _trader: WeakRef = null
var _order_mode: bool = false
var _capture: int = 0
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _refresh_remaining: float = 0.0
var _last_click_frame: int = -1
var _message: String = ""
var _last_signature: String = ""
var _quest_id: StringName = &""
var _title: Label = null
var _status: Label = null
var _offers: VBoxContainer = null
var _quest: VBoxContainer = null
var _close: Button = null
var _purchase_dialog: ConfirmationDialog = null
var _delivery_button: Button = null
var _purchase_item: DEF_InventoryItem = null
var _purchase_id: StringName = &""
var _purchase_focus: WeakRef = null


#region Создание и жизненный цикл
func _ready() -> void:
	layer = 95
	var root: MarginContainer = MarginContainer.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		root.add_theme_constant_override(side, int(MARGIN))
	add_child(root)

	var center: CenterContainer = CenterContainer.new()
	root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	panel.add_child(content)
	_title = Label.new()
	content.add_child(_title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	_offers = VBoxContainer.new()

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.y = 200.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_offers)
	_quest = VBoxContainer.new()
	content.add_child(_quest)
	_close = Button.new()
	_close.text = "Закрыть"
	_close.pressed.connect(close_panel)
	content.add_child(_close)
	_close.grab_focus()
	_create_purchase_dialog()


func _exit_tree() -> void:
	_release()


func _input(event: InputEvent) -> void:
	if _capture != 0 and event.is_action_pressed(&"menu"):
		if _purchase_item != null:
			_cancel_purchase()
		else:
			close_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var icons: Array[Texture2D] = InputPromptService.textures(&"menu")
	_close.icon = icons[0] if not icons.is_empty() else null
	if _capture == 0:
		return

	var trader: Entity = _shop()
	if not GrabService.holder_available(_actor) or _actor.has_component(C_Death) or (not _order_mode and (not GrabService.holder_available(trader) or trader.has_component(C_Death))):
		close_panel()
		return

	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = REFRESH_SECONDS
		_refresh()


#endregion

#region Модальный сеанс
## Захватывает ввод для торговли/заказа и запрашивает доступное задание торговца.
func open_for(actor: Entity, trader: Entity = null, order_mode: bool = false) -> bool:
	if _capture != 0 or not GrabService.holder_available(actor) or actor.has_component(C_Death) or CommerceService.current() == null:
		return false

	_actor = actor
	_trader = weakref(trader) if trader != null else null
	_order_mode = order_mode
	_capture = InteractionControlFocus.acquire(actor, self, InteractionControlFocus.Priority.MODAL)
	if _capture == 0:
		return false

	_previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _order_mode and trader != null:
		var record: RefusalQuestRecord = RefusalQuestService.offer(trader)
		_quest_id = record.quest_id if record != null else &""
	_refresh()
	return true


## Освобождает захват и режим мыши, затем удаляет панель.
func close_panel() -> void:
	_release()
	queue_free()


func _release() -> void:
	if _capture == 0:
		return

	_cancel_purchase(false)
	InteractionControlFocus.release(_actor, _capture)
	_capture = 0
	Input.mouse_mode = _previous_mouse if not is_instance_valid(_actor) or InteractionControlFocus.current(_actor) < InteractionControlFocus.Priority.MODAL else Input.MOUSE_MODE_VISIBLE


#endregion

#region Производное представление
func _shop() -> Entity:
	return _trader.get_ref() as Entity if _trader != null else null


func _refresh() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	var wallet: C_Wallet = WalletService.current()
	var commerce: C_Commerce = CommerceService.current()
	if cycle == null or wallet == null or commerce == null:
		return

	var shop: Entity = _shop()
	var shop_state: C_Trader = shop.get_component(C_Trader) as C_Trader if shop != null else null
	var profile: DEF_TraderProfile = shop_state.profile if shop_state != null else null
	var allowed: bool = cycle.phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.EVENING] if _order_mode else TraderCatalogRules.is_open(shop_state, cycle)
	_title.text = "Заказ на следующее утро" if _order_mode else profile.display_name if profile != null else "Торговец"
	var inventory: C_Inventory = _actor.get_component(C_Inventory) as C_Inventory
	var capacity: String = "%d / %d" % [InventoryService.items(_actor).size(), inventory.maximum_stacks] if inventory != null else "нет"
	_status.text = "День %d · деньги %d · инвентарь %s\nУсловие: %s · доставка в Morning дня %d\nЗадача: подготовьтесь к следующей смене. %s" % [cycle.day_index, wallet.balance, capacity, "заказы доступны" if allowed else "дождитесь Morning / Evening" if _order_mode else "торговец закрыт", cycle.day_index + 1, _message]
	if not _order_mode and shop_state != null:
		_status.text = "День %d · деньги %d · инвентарь %s\n%s · %s\nМебель: забрать в зоне возле торговца, перенести и закрепить молотком. %s" % [cycle.day_index, wallet.balance, capacity, TraderCatalogRules.schedule_text(shop_state), "открыто" if allowed else "закрыто", _message]

	var catalog: Array[DEF_InventoryItem] = commerce.catalog
	if not _order_mode and shop != null:
		catalog = TraderCatalogRules.catalog(shop_state)
	var record: RefusalQuestRecord = RefusalQuestService.find(_quest_id)
	var signature: String = "%d:%d:%d:%s:%s:%d" % [cycle.day_index, cycle.phase, wallet.balance, capacity, _message, record.state if record != null else -1]
	for item: DEF_InventoryItem in catalog:
		signature += "%s:%d;" % [item.key, item.market_price]
	if profile != null:
		signature += "%s:%s:%d:%d:%s" % [allowed, profile.display_name, profile.delivery_fee, profile.delivery_delay_days, profile.home_delivery_enabled]
	for delivery: PendingDelivery in commerce.pending_deliveries:
		signature += "%s:%d:%s;" % [delivery.delivery_id, delivery.delivery_day, delivery.fulfilled]
	if signature == _last_signature:
		return

	_last_signature = signature
	_clear(_offers)
	_clear(_quest)
	for item: DEF_InventoryItem in catalog:
		var row: VBoxContainer = VBoxContainer.new()
		_offers.add_child(row)
		var button: Button = Button.new()
		button.text = "%s · %d · %s" % [item.display_name, item.market_price, "Заказать ×1" if _order_mode else "Купить мебель" if item.kind == DEF_InventoryItem.Kind.FURNITURE else "Купить ×1"]
		button.disabled = not allowed or wallet.balance < item.market_price
		button.pressed.connect(_buy.bind(item))
		row.add_child(button)

	if _order_mode:
		for delivery: PendingDelivery in commerce.pending_deliveries:
			if not delivery.fulfilled:
				var label: Label = Label.new()
				label.text = "Ожидается: %s ×%d · утро дня %d" % [delivery.item.display_name, delivery.quantity, delivery.delivery_day]
				_quest.add_child(label)
	elif allowed and shop != null:
		_show_quest(record, cycle)


func _show_quest(record: RefusalQuestRecord, cycle: C_DayCycle) -> void:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if record == null:
		label.text = "Нет нового задания: нужна зарегистрированная посылка для будущего клиента."
	else:
		label.text = record.definition.offer_text.format({
			"number": "%03d" % record.display_number, "deadline": record.deadline_day,
			"days": maxi(0, record.deadline_day - cycle.day_index), "reward": record.reward,
		})
	_quest.add_child(label)
	if record == null:
		return
	if record.state == RefusalQuestRecord.State.OFFERED:
		for accept: bool in [true, false]:
			var button: Button = Button.new()
			button.text = record.definition.accept_text if accept else record.definition.ignore_text
			button.pressed.connect(_quest_choice.bind(record.quest_id, accept))
			_quest.add_child(button)
	elif record.state == RefusalQuestRecord.State.ACTIVE:
		var active: Label = Label.new()
		active.text = record.definition.accepted_text
		_quest.add_child(active)
	else:
		var resolved: Label = Label.new()
		resolved.text = "Исход задания: %s" % RefusalQuestRecord.State.keys()[record.state]
		_quest.add_child(resolved)


#endregion

#region Сервисные запросы
func _buy(item: DEF_InventoryItem) -> void:
	if _purchase_item != null or not _can_click():
		return

	var trader: Entity = _shop()
	var shop: C_Trader = trader.get_component(C_Trader) as C_Trader if trader != null else null
	var operation_id: StringName = CommerceService.next_id("order" if _order_mode else "buy")
	if not _order_mode and TraderCatalogRules.can_deliver(shop, item):
		_purchase_item = item
		_purchase_id = operation_id
		_purchase_focus = weakref(get_viewport().gui_get_focus_owner()) if get_viewport().gui_get_focus_owner() != null else null
		_purchase_dialog.dialog_text = "%s\nСамовывоз: %d$ · доставка: %d$\nДоставка утром дня %d." % [item.display_name, item.market_price, item.market_price + shop.profile.delivery_fee, DayPhaseService.current().day_index + shop.profile.delivery_delay_days]
		_delivery_button.text = "Доставить +%d$" % shop.profile.delivery_fee
		_delivery_button.disabled = WalletService.current().balance < item.market_price + shop.profile.delivery_fee
		_purchase_dialog.popup_centered()
		_purchase_dialog.get_ok_button().grab_focus()
		return

	_submit_purchase(item, operation_id, false)


func _submit_purchase(item: DEF_InventoryItem, operation_id: StringName, delivered: bool) -> void:
	var result: CommerceService.Status = CommerceService.order(_actor, item, 1, operation_id) if _order_mode else CommerceService.home_delivery(_actor, _shop(), item, 1, operation_id) if delivered else CommerceService.purchase(_actor, _shop(), item, 1, operation_id)
	_message = RESULT_TEXT[result]
	_refresh()


#endregion

#region Выбор способа получения
func _create_purchase_dialog() -> void:
	_purchase_dialog = ConfirmationDialog.new()
	_purchase_dialog.name = "FurniturePurchase"
	_purchase_dialog.title = "Доставить или заберёшь сам?"
	_purchase_dialog.exclusive = true
	_purchase_dialog.min_size = Vector2i(420, 160)
	_purchase_dialog.get_ok_button().text = "Сам"
	_purchase_dialog.get_cancel_button().text = "Отмена"
	_delivery_button = _purchase_dialog.add_button("Доставить +100$", true, &"delivery")
	_purchase_dialog.confirmed.connect(_choose_purchase.bind(false))
	_purchase_dialog.custom_action.connect(_delivery_choice)
	_purchase_dialog.canceled.connect(_cancel_purchase)
	add_child(_purchase_dialog)


func _delivery_choice(action: StringName) -> void:
	if action == &"delivery":
		_choose_purchase(true)


func _choose_purchase(delivered: bool) -> void:
	if _purchase_item == null or not _has_input():
		return

	_last_click_frame = Engine.get_process_frames()
	var item: DEF_InventoryItem = _purchase_item
	var operation_id: StringName = _purchase_id
	# Удаляем запрос до побочных эффектов; повторный сигнал уже не имеет покупки.
	_cancel_purchase(false)
	_submit_purchase(item, operation_id, delivered)
	_close.grab_focus()


func _cancel_purchase(restore_focus: bool = true) -> void:
	_purchase_item = null
	_purchase_id = &""
	if _purchase_dialog != null:
		_purchase_dialog.hide()

	var previous: Control = _purchase_focus.get_ref() as Control if _purchase_focus != null else null
	_purchase_focus = null
	if restore_focus and _capture != 0:
		if is_instance_valid(previous) and previous.is_inside_tree() and not previous.is_queued_for_deletion():
			previous.grab_focus()
		elif _close != null:
			_close.grab_focus()


#endregion

#region Сервисные запросы

func _quest_choice(quest_id: StringName, accept: bool) -> void:
	if not _can_click():
		return

	var applied: bool = RefusalQuestService.accept(quest_id) if accept else RefusalQuestService.ignore(quest_id)
	_message = "Решение сохранено" if applied else "Задание недоступно"
	_refresh()


func _can_click() -> bool:
	var frame: int = Engine.get_process_frames()
	if frame == _last_click_frame or not _has_input():
		return false

	_last_click_frame = frame
	return true


func _has_input() -> bool:
	return _capture != 0 and GrabService.holder_available(_actor) and InteractionControlFocus.current(_actor, _capture) < InteractionControlFocus.Priority.MODAL


func _clear(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

#endregion
