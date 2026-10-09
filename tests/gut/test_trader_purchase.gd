extends "res://tests/gut/test_trader_furniture.gd"
## Финансовые и модальные регрессии дневного торговца и выбора доставки только крупной мебели.

#region Доступность и авторские ограничения
## Two authored Profiles change actual offers and availability without changing transaction code.
func test_authored_profile_variants_are_the_only_live_shop_assortment() -> void:
	var general: DEF_TraderProfile = load("res://content/domains/commerce/definitions/def_trader_default.tres") as DEF_TraderProfile
	var medical: DEF_TraderProfile = load("res://content/domains/commerce/definitions/def_trader_medical.tres") as DEF_TraderProfile
	var food: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_food.tres") as DEF_InventoryItem
	var medicine: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_med.tres") as DEF_InventoryItem
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
	assert_eq(CommerceService.purchase(_actor, _trader, food, 1, &"medical/food"), CommerceService.Status.INVALID)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_eq(CommerceService.purchase(_actor, _trader, medicine, 1, &"medical/medicine"), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 1000 - medicine.market_price)
	assert_eq((InventoryService.items(_actor)[0].get_component(C_InventoryItem) as C_InventoryItem).definition, medicine)
	assert_eq(CommerceService.order(_actor, medicine, 1, &"terminal/medicine"), CommerceService.Status.INVALID)
	assert_eq(_commerce.receipts.size(), 1)


## Покупка и доставка доступны в трёх игровых фазах, но никогда в техническую ночь.
func test_default_trader_purchases_and_delivery_in_all_live_phases() -> void:
	var food: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_food.tres") as DEF_InventoryItem
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		_cycle.phase = phase
		assert_true(TraderCatalogRules.is_open(_shop, _cycle))
		assert_eq(CommerceService.purchase(_actor, _trader, food, 1, StringName("phase/food/%d" % phase)), CommerceService.Status.COMMITTED)
		assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, StringName("phase/shelf/%d" % phase)), CommerceService.Status.COMMITTED)
	assert_eq(_wallet.balance, 85)
	assert_eq(_commerce.pending_deliveries.size(), 3)
	assert_eq(_commerce.receipts.size(), 6)
	_cycle.phase = C_DayCycle.Phase.NIGHT
	assert_false(TraderCatalogRules.is_open(_shop, _cycle))
	assert_eq(CommerceService.purchase(_actor, _trader, food, 1, &"night/food"), CommerceService.Status.WRONG_PHASE)
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"night/shelf"), CommerceService.Status.WRONG_PHASE)
	assert_eq(_wallet.balance, 85)


## Вид, авторский признак, профиль и количество проверяются сервисом даже при обходе UI.
func test_delivery_rejects_consumables_unmarked_furniture_and_disabled_profile() -> void:
	for key: String in ["food", "med", "bubble_wrap"]:
		var item: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_%s.tres" % key) as DEF_InventoryItem
		assert_false(TraderCatalogRules.can_deliver(_shop, item))
		assert_eq(CommerceService.home_delivery(_actor, _trader, item, 1, StringName(key)), CommerceService.Status.INVALID)
	var unmarked: DEF_InventoryItem = _shelf.duplicate() as DEF_InventoryItem
	unmarked.bulky_furniture = false
	var profile: DEF_TraderProfile = _shop.profile.duplicate() as DEF_TraderProfile
	profile.catalog = [unmarked]
	_shop.profile = profile
	assert_eq(CommerceService.home_delivery(_actor, _trader, unmarked, 1, &"unmarked"), CommerceService.Status.INVALID)
	unmarked.bulky_furniture = true
	unmarked.kind = DEF_InventoryItem.Kind.FOOD
	assert_eq(CommerceService.home_delivery(_actor, _trader, unmarked, 1, &"wrong_kind"), CommerceService.Status.INVALID)
	profile.catalog = [_shelf]
	profile.home_delivery_enabled = false
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"disabled"), CommerceService.Status.INVALID)
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
	var button: Button = panel._offers.get_child(0).get_child(0) as Button
	button.grab_focus()
	button.pressed.emit()
	return panel


## Обычные товары покупаются сразу и не показывают выбор доставки.
func test_consumables_buy_without_popup_or_delivery_option() -> void:
	var panel: CommercePanel = CommercePanelFactory.open(_actor, _trader)
	for index: int in 3:
		assert_eq(panel._offers.get_child(index).get_child_count(), 1)
	(panel._offers.get_child(0).get_child(0) as Button).pressed.emit()
	assert_false(panel._purchase_dialog.visible)
	assert_null(panel._purchase_item)
	assert_eq(_wallet.balance, 975)
	assert_eq(InventoryService.items(_actor).size(), 1)
	assert_true(_commerce.pending_deliveries.is_empty())


## Отмена и Back не списывают деньги; повторный сигнал не покупает товар и захват остаётся единым.
func test_cancel_and_menu_preserve_money_and_release_modal_only_on_panel_close() -> void:
	var panel: CommercePanel = _open_choice()
	var control: C_GrabControl = _actor.get_component(C_GrabControl) as C_GrabControl
	assert_eq(control.captures.size(), 1)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	assert_true(panel._purchase_dialog.visible)
	panel._purchase_dialog.canceled.emit()
	assert_false(panel._purchase_dialog.visible)
	assert_null(panel._purchase_item)
	assert_true((panel._offers.get_child(0).get_child(0) as Button).has_focus())
	await get_tree().process_frame
	panel._purchase_dialog.custom_action.emit(&"delivery")
	assert_eq(_wallet.balance, 1000)
	await get_tree().process_frame
	panel._buy(_shelf)
	assert_true(panel._purchase_dialog.visible)
	var back: InputEventAction = InputEventAction.new()
	back.action = &"menu"
	back.pressed = true
	panel._input(back)
	assert_false(panel._purchase_dialog.visible)
	assert_ne(panel._capture, 0)
	assert_false(panel.is_queued_for_deletion())
	assert_eq(control.captures.size(), 1, "Back closes the choice, keeping the storefront open")
	assert_true(_wallet.operations.is_empty())
	panel.close_panel()
	assert_true(control.captures.is_empty())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


## Один выбор доставки фиксирует одну оплату и один заказ, сохраняемый существующим кодеком.
func test_popup_delivery_duplicate_answer_and_round_trip_do_not_repay() -> void:
	var panel: CommercePanel = _open_choice()
	var operation_id: StringName = panel._purchase_id
	assert_eq(_wallet.balance, 1000)
	await get_tree().process_frame
	panel._purchase_dialog.custom_action.emit(&"delivery")
	panel._purchase_dialog.custom_action.emit(&"delivery")
	panel._purchase_dialog.confirmed.emit()
	assert_false(panel._purchase_dialog.visible)
	assert_eq(_wallet.balance, 720)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_commerce.receipts.size(), 1)
	assert_eq(_commerce.pending_deliveries.size(), 1)
	assert_true(_world.query.with_all([C_Anchorable]).execute().is_empty())
	var copy: C_Commerce = C_Commerce.new()
	assert_true(SaveDataCodec.apply_fields(copy, SaveDataCodec.component_data(_commerce).fields as Dictionary))
	assert_eq(copy.receipts[0].operation_id, operation_id)
	assert_eq(copy.receipts[0].delivery_fee, 100)
	assert_eq(copy.receipts[0].total_price, 280)
	assert_eq(copy.pending_deliveries[0].delivery_id, operation_id)
	assert_same(copy.pending_deliveries[0].item, _shelf)
	assert_eq(copy.pending_deliveries[0].ordered_day, 1)
	assert_eq(copy.pending_deliveries[0].delivery_day, 2)
	assert_false(copy.pending_deliveries[0].fulfilled)
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, operation_id), CommerceService.Status.DUPLICATE)
	panel.close_panel()
	assert_eq(_wallet.balance, 720)


## Самовывоз через тот же попап сохраняет физическую выдачу без платы за доставку.
func test_popup_pickup_creates_one_physical_item_and_no_delivery() -> void:
	var panel: CommercePanel = _open_choice()
	var operation_id: StringName = panel._purchase_id
	await get_tree().process_frame
	panel._purchase_dialog.confirmed.emit()
	panel._purchase_dialog.confirmed.emit()
	panel._purchase_dialog.custom_action.emit(&"delivery")
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
	assert_false(panel._delivery_button.disabled)
	_wallet.balance = 200
	await get_tree().process_frame
	panel._purchase_dialog.custom_action.emit(&"delivery")
	assert_eq(_wallet.balance, 200)
	assert_true(_wallet.operations.is_empty())
	assert_true(_commerce.receipts.is_empty())
	assert_true(_commerce.pending_deliveries.is_empty())
	assert_null(panel._purchase_item)
	assert_eq(panel._message, "Недостаточно денег")


## Исчезнувший, умерший или отключённый торговец не принимает оплату.
func test_unavailable_trader_at_answer_cancels_purchase_and_releases_control() -> void:
	var panel: CommercePanel = _open_choice()
	panel.set_process(false)
	await get_tree().process_frame
	_world.disable_entity(_trader)
	panel._purchase_dialog.custom_action.emit(&"delivery")
	assert_eq(_wallet.balance, 1000)
	assert_true(_commerce.pending_deliveries.is_empty())
	assert_true(_wallet.operations.is_empty())
	panel._process(0.0)
	assert_eq(panel._capture, 0)
	assert_true((_actor.get_component(C_GrabControl) as C_GrabControl).captures.is_empty())
	_world.enable_entity(_trader)
	_trader.add_component(C_Death.new())
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"dead"), CommerceService.Status.INVALID)
	assert_eq(CommerceService.purchase(_actor, _trader, _shelf, 1, &"dead"), CommerceService.Status.INVALID)
	_trader.remove_component(C_Death)
	_world.remove_entity(_trader)
	assert_eq(CommerceService.home_delivery(_actor, _trader, _shelf, 1, &"removed"), CommerceService.Status.INVALID)
	assert_eq(_wallet.balance, 1000)
#endregion


#region Domain requests and native UI composition
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
