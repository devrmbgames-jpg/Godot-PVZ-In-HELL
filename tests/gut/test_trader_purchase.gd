extends "res://tests/gut/test_trader_furniture.gd"
## Финансовые и модальные регрессии дневного торговца и выбора доставки только крупной мебели.

const DEF_ITEM_FOOD_PATH: String = (
	"res://content/domains/inventory/definitions/def_item_food.tres"
)
const DEF_ITEM_MED_PATH: String = "res://content/domains/inventory/definitions/def_item_med.tres"


#region Доступность и авторские ограничения
## Two authored Profiles change actual offers and availability without changing transaction code.
func test_authored_profile_variants_are_the_only_live_shop_assortment() -> void:
	var general: DEF_TraderProfile = (
		load("res://content/domains/commerce/definitions/def_trader_default.tres")
		as DEF_TraderProfile
	)
	var medical: DEF_TraderProfile = (
		load("res://content/domains/commerce/definitions/def_trader_medical.tres")
		as DEF_TraderProfile
	)
	var food: DEF_InventoryItem = (load(DEF_ITEM_FOOD_PATH) as DEF_InventoryItem)
	var medicine: DEF_InventoryItem = load(DEF_ITEM_MED_PATH) as DEF_InventoryItem
	assert_same(_shop.profile, general)
	assert_true(food in TraderCatalogRules.catalog(_shop))
	assert_true(_shelf in TraderCatalogRules.catalog(_shop))

	_shop.profile = medical
	_commerce.catalog = [food]
	_cycle.phase = C_DayCycle.Phase.MORNING
	assert_false(TraderCatalogRules.is_open(_shop, _cycle))
	_cycle.day_index = 2
	assert_true(TraderCatalogRules.is_open(_shop, _cycle))
	assert_eq(TraderCatalogRules.catalog(_shop), [medicine])
	assert_eq(
		CommerceService.purchase(_actor, _trader, food, 1, &"medical/food"),
		CommerceService.Status.INVALID,
	)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_eq(
		CommerceService.purchase(_actor, _trader, medicine, 1, &"medical/medicine"),
		CommerceService.Status.COMMITTED,
	)
	assert_eq(_wallet.balance, 1000 - medicine.market_price)
	assert_eq(
		(
			InventoryService.items(_actor)[0].get_component(C_InventoryItem) as C_InventoryItem
		).definition,
		medicine,
	)
	assert_eq(
		CommerceService.order(_actor, medicine, 1, &"terminal/medicine"),
		CommerceService.Status.INVALID,
	)
	assert_eq(_commerce.receipts.size(), 1)


## Покупка и доставка доступны в трёх игровых фазах, но никогда в техническую ночь.
func test_default_trader_purchases_and_delivery_in_all_live_phases() -> void:
	var food: DEF_InventoryItem = (load(DEF_ITEM_FOOD_PATH) as DEF_InventoryItem)
	for phase: C_DayCycle.Phase in ([
		C_DayCycle.Phase.MORNING,
		C_DayCycle.Phase.DAY,
		C_DayCycle.Phase.EVENING,
	]):
		_cycle.phase = phase
		assert_true(TraderCatalogRules.is_open(_shop, _cycle))
		assert_eq(
			CommerceService.purchase(_actor, _trader, food, 1, StringName("phase/food/%d" % phase)),
			CommerceService.Status.COMMITTED,
		)
		assert_eq(
			CommerceService.home_delivery(
				_actor,
				_trader,
				_shelf,
				1,
				StringName("phase/shelf/%d" % phase),
			),
			CommerceService.Status.COMMITTED,
		)
	assert_eq(_wallet.balance, 85)
	assert_eq(_commerce.pending_deliveries.size(), 3)
	assert_eq(_commerce.receipts.size(), 6)
	_cycle.phase = C_DayCycle.Phase.NIGHT
	assert_false(TraderCatalogRules.is_open(_shop, _cycle))
	assert_eq(
		CommerceService.purchase(_actor, _trader, food, 1, &"night/food"),
		CommerceService.Status.WRONG_PHASE,
	)
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"night/shelf"),
		CommerceService.Status.WRONG_PHASE,
	)
	assert_eq(_wallet.balance, 85)


## Вид, авторский признак, профиль и количество проверяются сервисом даже при обходе UI.
func test_delivery_rejects_consumables_unmarked_furniture_and_disabled_profile() -> void:
	for key: String in ["food", "med", "bubble_wrap"]:
		var item: DEF_InventoryItem = (
			load("res://content/domains/inventory/definitions/def_item_%s.tres" % key)
			as DEF_InventoryItem
		)
		assert_false(TraderCatalogRules.can_deliver(_shop, item))
		assert_eq(
			CommerceService.home_delivery(_actor, _trader, item, 1, StringName(key)),
			CommerceService.Status.INVALID,
		)
	var unmarked: DEF_InventoryItem = _shelf.duplicate() as DEF_InventoryItem
	unmarked.bulky_furniture = false
	var profile: DEF_TraderProfile = _shop.profile.duplicate() as DEF_TraderProfile
	profile.catalog = [unmarked]
	_shop.profile = profile
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, unmarked, 1, &"unmarked"),
		CommerceService.Status.INVALID,
	)
	unmarked.bulky_furniture = true
	unmarked.kind = DEF_InventoryItem.Kind.FOOD
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, unmarked, 1, &"wrong_kind"),
		CommerceService.Status.INVALID,
	)
	profile.catalog = [_shelf]
	profile.home_delivery_enabled = false
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"disabled"),
		CommerceService.Status.INVALID,
	)
	assert_eq(_wallet.balance, 1000)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_true(_commerce.pending_deliveries.is_empty())
#endregion


#region Отдельный выбор и повторные сигналы
func _open_choice() -> CommercePanel:
	var profile: DEF_TraderProfile = _shop.profile.duplicate() as DEF_TraderProfile
	profile.catalog = [_shelf]
	_shop.profile = profile
	var panel: CommercePanel = CommercePanelFactory.open(_actor, _trader)
	var button: Button = panel.get("_offers").get_child(0).get_child(0) as Button
	button.grab_focus()
	button.pressed.emit()
	return panel


## Обычные товары покупаются сразу и не показывают выбор доставки.
func test_consumables_buy_without_popup_or_delivery_option() -> void:
	var panel: CommercePanel = CommercePanelFactory.open(_actor, _trader)
	for index: int in 3:
		assert_eq(panel.get("_offers").get_child(index).get_child_count(), 1)
	(panel.get("_offers").get_child(0).get_child(0) as Button).pressed.emit()
	assert_false(panel.get("_purchase_dialog").visible)
	assert_null(panel.get("_purchase_item"))
	assert_eq(_wallet.balance, 975)
	assert_eq(InventoryService.items(_actor).size(), 1)
	assert_true(_commerce.pending_deliveries.is_empty())


## Отмена и Back не списывают деньги; повторный сигнал не покупает товар и захват остаётся единым.
func test_cancel_and_menu_preserve_money_and_release_modal_only_on_panel_close() -> void:
	var panel: CommercePanel = _open_choice()
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	assert_eq(control.captures.size(), 1)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	assert_true(panel.get("_purchase_dialog").visible)
	panel.get("_purchase_dialog").canceled.emit()
	assert_false(panel.get("_purchase_dialog").visible)
	assert_null(panel.get("_purchase_item"))
	assert_true((panel.get("_offers").get_child(0).get_child(0) as Button).has_focus())
	await get_tree().process_frame
	panel.get("_purchase_dialog").custom_action.emit(&"delivery")
	assert_eq(_wallet.balance, 1000)
	await get_tree().process_frame
	panel.call("_buy", _shelf)
	assert_true(panel.get("_purchase_dialog").visible)
	var back: InputEventAction = InputEventAction.new()
	back.action = &"menu"
	back.pressed = true
	panel.call("_input", back)
	assert_false(panel.get("_purchase_dialog").visible)
	assert_ne(panel.get("_capture"), 0)
	assert_false(panel.is_queued_for_deletion())
	assert_eq(control.captures.size(), 1, "Back closes the choice, keeping the storefront open")
	assert_true(_wallet.operations.is_empty())
	panel.close_panel()
	assert_true(control.captures.is_empty())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


## Один выбор доставки фиксирует одну оплату и один заказ, сохраняемый существующим кодеком.
func test_popup_delivery_duplicate_answer_and_round_trip_do_not_repay() -> void:
	var panel: CommercePanel = _open_choice()
	var operation_id: StringName = panel.get("_purchase_id")
	assert_eq(_wallet.balance, 1000)
	await get_tree().process_frame
	panel.get("_purchase_dialog").custom_action.emit(&"delivery")
	panel.get("_purchase_dialog").custom_action.emit(&"delivery")
	panel.get("_purchase_dialog").confirmed.emit()
	assert_false(panel.get("_purchase_dialog").visible)
	assert_eq(_wallet.balance, 720)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_commerce.receipts.size(), 1)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_true(_world.query.with_all([C_Anchorable]).execute().is_empty())
	var copy: C_Commerce = C_Commerce.new()
	assert_true(
		SaveDataCodec.apply_fields(
			copy,
			SaveDataCodec.component_data(_commerce).fields as Dictionary,
		)
	)
	assert_eq(copy.receipts[0].operation_id, operation_id)
	assert_eq(copy.receipts[0].delivery_fee, 100)
	assert_eq(copy.receipts[0].total_price, 280)
	assert_eq(copy.pending_deliveries[0].delivery_id, operation_id)
	assert_same(copy.pending_deliveries[0].item, _shelf)
	assert_eq(copy.pending_deliveries[0].ordered_day, 1)
	assert_eq(copy.pending_deliveries[0].delivery_day, 2)
	assert_false(copy.pending_deliveries[0].fulfilled)
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, _shelf, 1, operation_id),
		CommerceService.Status.DUPLICATE,
	)
	panel.close_panel()
	assert_eq(_wallet.balance, 720)


## Самовывоз через тот же попап сохраняет физическую выдачу без платы за доставку.
func test_popup_pickup_creates_one_physical_item_and_no_delivery() -> void:
	var panel: CommercePanel = _open_choice()
	var operation_id: StringName = panel.get("_purchase_id")
	await get_tree().process_frame
	panel.get("_purchase_dialog").confirmed.emit()
	panel.get("_purchase_dialog").confirmed.emit()
	panel.get("_purchase_dialog").custom_action.emit(&"delivery")
	assert_not_null(_goods("purchase/%s" % operation_id))
	assert_eq(_world.query.with_all([C_Anchorable]).execute().size(), 1)
	assert_eq(_wallet.balance, 820)
	assert_eq(_wallet.operations.size(), 1)
	assert_true(_commerce.pending_deliveries.is_empty())
#endregion


#region Изменение условий до ответа
## Баланс повторно проверяется при ответе, даже если доставка была доступна при открытии.
func test_money_change_after_popup_never_leaves_a_paid_receipt_or_order() -> void:
	var panel: CommercePanel = _open_choice()
	assert_false(panel.get("_delivery_button").disabled)
	_wallet.balance = 200
	await get_tree().process_frame
	panel.get("_purchase_dialog").custom_action.emit(&"delivery")
	assert_eq(_wallet.balance, 200)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_true(_commerce.pending_deliveries.is_empty())
	assert_null(panel.get("_purchase_item"))
	assert_eq(panel.get("_message"), "Недостаточно денег")


## Исчезнувший, умерший или отключённый торговец не принимает оплату.
func test_unavailable_trader_at_answer_cancels_purchase_and_releases_control() -> void:
	var panel: CommercePanel = _open_choice()
	panel.set_process(false)
	await get_tree().process_frame
	_world.disable_entity(_trader)
	panel.get("_purchase_dialog").custom_action.emit(&"delivery")
	assert_eq(_wallet.balance, 1000)
	assert_true(_commerce.pending_deliveries.is_empty())
	assert_true(_wallet.operations.is_empty())
	panel.call("_process", 0.0)
	assert_eq(panel.get("_capture"), 0)
	assert_true((_actor.get_component(C_GrabControl) as C_GrabControl).captures.is_empty())
	_world.enable_entity(_trader)
	_trader.add_component(C_Death.new())
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"dead"),
		CommerceService.Status.INVALID,
	)
	assert_eq(
		CommerceService.purchase(_actor, _trader, _shelf, 1, &"dead"),
		CommerceService.Status.INVALID,
	)
	_trader.remove_component(C_Death)
	_world.remove_entity(_trader)
	assert_eq(
		CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"removed"),
		CommerceService.Status.INVALID,
	)
	assert_eq(_wallet.balance, 1000)
#endregion


#region Domain requests and native UI composition
## The permanent scaffold exists in the PackedScene before any runtime callbacks.
func test_authored_commerce_scene_exposes_layout_and_dialog_before_ready() -> void:
	var packed: PackedScene = load("res://content/ui/commerce_panel.tscn") as PackedScene
	var panel: CommercePanel = packed.instantiate() as CommercePanel
	assert_false(panel.is_node_ready())
	assert_eq(panel.layer, 95)
	var margin: MarginContainer = panel.get_node("Root") as MarginContainer
	assert_eq(margin.anchor_right, 1.0)
	assert_eq(margin.anchor_bottom, 1.0)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		assert_eq(margin.get_theme_constant(side), 32)
	var body: PanelContainer = panel.get_node("Root/Center/Panel") as PanelContainer
	assert_eq(body.custom_minimum_size, Vector2(720, 450))
	var scroll: ScrollContainer = body.get_node("Content/OffersScroll") as ScrollContainer
	assert_eq(scroll.custom_minimum_size.y, 200.0)
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(scroll.size_flags_vertical, Control.SIZE_EXPAND_FILL)
	assert_true(scroll.has_node("Offers"))
	assert_true(body.has_node("Content/Quest"))
	assert_eq((body.get_node("Content/CloseButton") as Button).text, "Закрыть")
	var dialog: ConfirmationDialog = panel.get_node("FurniturePurchase") as ConfirmationDialog
	assert_true(dialog.exclusive)
	assert_eq(dialog.min_size, Vector2i(420, 160))
	assert_eq(dialog.ok_button_text, "Сам")
	assert_eq(dialog.cancel_button_text, "Отмена")
	assert_true(dialog.has_node("DeliveryButton"))
	assert_true(dialog.has_node("DeliverySpacer"))
	assert_same(dialog.get_node("DeliveryButton").owner, panel)
	panel.free()


## Repeated openings bind one close handler and release the previous mouse/control state.
func test_scene_reopen_and_close_button_keep_one_capture_and_one_handler() -> void:
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var accepted_mouse: Input.MouseMode = Input.mouse_mode
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	for attempt: int in 2:
		var panel: CommercePanel = CommercePanelFactory.open(_actor, _trader)
		assert_not_null(panel)
		assert_eq(panel.scene_file_path, "res://content/ui/commerce_panel.tscn")
		assert_null(CommercePanelFactory.open(_actor, _trader))
		assert_false(panel.open_for(_actor, _trader))
		assert_eq(control.captures.size(), 1)
		var close_button: Button = panel.get("_close") as Button
		assert_eq(close_button.pressed.get_connections().size(), 1)
		close_button.pressed.emit()
		assert_true(control.captures.is_empty())
		assert_eq(Input.mouse_mode, accepted_mouse)
		await get_tree().process_frame
	Input.mouse_mode = previous_mouse


## Authored delivery button uses the same custom action and commits one operation on double signal.
func test_authored_delivery_button_joins_native_row_and_routes_one_purchase() -> void:
	var panel: CommercePanel = _open_choice()
	var dialog: ConfirmationDialog = panel.get("_purchase_dialog") as ConfirmationDialog
	var delivery: Button = panel.get("_delivery_button") as Button
	var spacer: Control = panel.get("_delivery_spacer") as Control
	assert_same(delivery.get_parent(), dialog.get_ok_button().get_parent())
	assert_same(spacer.get_parent(), delivery.get_parent())
	assert_eq(spacer.get_index(), delivery.get_index() + 1)
	assert_eq(spacer.size_flags_horizontal, Control.SIZE_EXPAND_FILL)
	assert_eq(spacer.mouse_filter, Control.MOUSE_FILTER_PASS)
	assert_eq(delivery.pressed.get_connections().size(), 1)
	await get_tree().process_frame
	delivery.pressed.emit()
	delivery.pressed.emit()
	assert_false(dialog.visible)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_eq(_wallet.balance, 720)


## Terminal mode projects its own changing catalog and queues an order without the delivery choice.
func test_authored_scene_order_mode_refreshes_variable_catalog_and_submits_once() -> void:
	_commerce.catalog = [load(DEF_ITEM_FOOD_PATH) as DEF_InventoryItem]
	var panel: CommercePanel = CommercePanelFactory.open(_actor, null, true)
	assert_not_null(panel)
	assert_eq((panel.get("_offers") as VBoxContainer).get_child_count(), 1)
	var button: Button = panel.get("_offers").get_child(0).get_child(0) as Button
	button.pressed.emit()
	button.pressed.emit()
	assert_eq(_commerce.receipts.size(), 1)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_eq(_wallet.balance, 975)
	assert_false((panel.get("_purchase_dialog") as ConfirmationDialog).visible)
	_commerce.catalog.append(load(DEF_ITEM_MED_PATH) as DEF_InventoryItem)
	panel.call("_refresh")
	assert_eq((panel.get("_offers") as VBoxContainer).get_child_count(), 2)
	_cycle.phase = C_DayCycle.Phase.DAY
	panel.call("_refresh")
	assert_true((panel.get("_offers").get_child(0).get_child(0) as Button).disabled)
	assert_eq(_commerce.receipts.size(), 1)


## Failed acquire deletes the instantiated shell; tree exit also releases an active capture.
func test_failed_scene_open_and_tree_exit_leave_no_modal_capture() -> void:
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	_actor.remove_component(C_GrabControl)
	assert_null(CommercePanelFactory.open(_actor, _trader))
	await get_tree().process_frame
	for child: Node in _actor.get_children():
		assert_false(child is CommercePanel)
	_actor.add_component(control)
	var panel: CommercePanel = _open_choice()
	assert_eq(control.captures.size(), 1)
	_actor.remove_child(panel)
	assert_true(control.captures.is_empty())
	assert_null(panel.get("_purchase_item"))
	panel.free()


## Disabling the actor closes even a pending furniture choice without requesting a purchase.
func test_unavailable_actor_closes_authored_panel_without_payment() -> void:
	var panel: CommercePanel = _open_choice()
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	_world.disable_entity(_actor)
	panel.call("_process", 0.0)
	assert_true(panel.is_queued_for_deletion())
	assert_true(control.captures.is_empty())
	assert_eq(_wallet.balance, 1000)
	assert_true(_commerce.receipts.is_empty())
	_world.enable_entity(_actor)


## The actual interaction opens native UI; Night cleanup releases the same modal capture.
func test_trader_action_request_opens_panel_and_night_reset_closes_it() -> void:
	DialogueUiFixture.install()
	var action: DEF_TraderAction = DEF_TraderAction.new()
	assert_true(action.is_available(_actor, _trader, _trader))
	action.execute(_actor, _trader, _trader)

	var panels: Array[CommercePanel] = []
	for child: Node in _actor.get_children():
		if child is CommercePanel:
			panels.append(child as CommercePanel)
	assert_eq(panels.size(), 1)
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	assert_eq(control.captures.size(), 1)

	NightResetService.reset()
	assert_true(control.captures.is_empty())
	assert_true(panels[0].is_queued_for_deletion())
	assert_eq(_wallet.balance, 1000)
	assert_true(_commerce.receipts.is_empty())


## A request captured before role replacement cannot open a shop for the new Component.
func test_captured_commerce_request_rejects_replaced_trader_role() -> void:
	DialogueUiFixture.install()
	var request: CommercePanelOpenRequest = CommercePanelOpenRequest.new(_actor, _trader)
	_trader.remove_component(C_Trader)
	var replacement: C_Trader = C_Trader.new()
	replacement.profile = _shop.profile
	_trader.add_component(replacement)

	_world.emit_event(CommercePanelOpenRequest.EVENT, _trader, request)
	assert_false(request.opened)
	assert_true((_actor.get_component(C_GrabControl) as C_GrabControl).captures.is_empty())
	assert_eq(_wallet.balance, 1000)


## Unregistered actors cannot reacquire a modal through a previously captured request.
func test_captured_commerce_request_rejects_removed_actor() -> void:
	DialogueUiFixture.install()
	var request: CommercePanelOpenRequest = CommercePanelOpenRequest.new(_actor, _trader)
	_world.remove_entity(_actor)

	_world.emit_event(CommercePanelOpenRequest.EVENT, _trader, request)
	assert_false(request.opened)
	assert_eq(_wallet.balance, 1000)
#endregion
