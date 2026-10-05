extends Node
## Два процесса реального района: выбор у торговца, оплата и восстановление ожидающего заказа мебели.

const SAVE_PATH: String = "user://trader_purchase_smoke.pvzh"
const MAX_RECEIVING_FRAMES: int = 900
const INITIAL_BALANCE: int = 1000

var _failed: bool = false

#region Район и проверка оплаченного заказа
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup()
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	if restoring:
		level.set_physics_process(false)
		var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(WorldSnapshotService.valid(snapshot, level), "full district snapshot validates")
		_check(WorldSnapshotService.restore(snapshot, level), "new process restores full district")
		if not _failed:
			_check_order()
		_cleanup()
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowService.current().visits.size() == 5:
				break
		level.set_physics_process(false)
		_check(CustomerFlowService.current().visits.size() == 5, "real receiving batch ready")
		if not _failed:
			await _buy(level)
	print("Trader purchase smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _buy(level: Node3D) -> void:
	var player: Entity = level.get_node("Entityes/Player") as Entity
	var merchant: E_DistrictNpc = NpcActivityService.merchant()
	_check(GrabService.holder_available(merchant), "permanent merchant available in morning")
	if _failed:
		return

	var cycle: C_DayCycle = DayPhaseService.current()
	var person: NpcRecord = DistrictPopulationService.person_for((merchant.get_component(C_NpcIdentity) as C_NpcIdentity).npc_id)
	var shop: C_Trader = merchant.get_component(C_Trader) as C_Trader
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		cycle.phase = phase
		DistrictPopulationService.plan_phase(person, 1, phase)
		_check(person.profile.schedule.location_for(1, phase) == DEF_NpcSchedule.Location.STREET, "merchant schedule stays local")
		_check(TraderCatalogService.is_open(shop, cycle), "profile allows live phase")
	cycle.phase = C_DayCycle.Phase.DAY
	WalletService.current().balance = INITIAL_BALANCE
	var shelf: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_large_shelf.tres") as DEF_InventoryItem
	var panel: CommercePanel = CommercePanelService.open(player, merchant)
	_check(panel != null, "real player opens shop in day")
	if _failed:
		return

	var button: Button = null
	for row: Node in panel._offers.get_children():
		_check(row.get_child_count() == 1, "catalog has no direct delivery buttons")
		var candidate: Button = row.get_child(0) as Button
		if candidate.text.begins_with(shelf.display_name):
			button = candidate
	_check(button != null, "authored shelf is stocked")
	if button == null:
		panel.close_panel()
		return
	button.pressed.emit()
	_check(panel._purchase_dialog.visible, "furniture opens separate choice")
	_check(panel._delivery_button.text == "Доставить +100$", "explicit delivery price")
	_check(WalletService.current().balance == INITIAL_BALANCE, "opening choice does not charge")
	panel._purchase_dialog.canceled.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	button.pressed.emit()
	await get_tree().process_frame
	panel._purchase_dialog.custom_action.emit(&"delivery")
	panel._purchase_dialog.custom_action.emit(&"delivery")
	_check_order()
	panel.close_panel()
	await get_tree().process_frame
	_check(InteractionControlFocus.current(player) < InteractionControlFocus.Priority.MODAL, "closing shop releases control")
	if not _failed:
		var snapshot: Dictionary = WorldSnapshotService.capture(level, 1)
		_check(WorldSnapshotService.valid(snapshot, level), "paid full snapshot validates before write")
		_check(AutosaveStore.write(snapshot, SAVE_PATH) == OK, "paid order written to own disk slot")

func _check_order() -> void:
	var commerce: C_Commerce = CommerceService.current()
	var wallet: C_Wallet = WalletService.current()
	_check(wallet.balance == 720, "item and 100 fee charged exactly once")
	_check(commerce.receipts.size() == 1 and commerce.pending_deliveries.size() == 1, "one receipt and one pending order")
	if commerce.receipts.size() != 1 or commerce.pending_deliveries.size() != 1:
		return

	var receipt: PurchaseReceipt = commerce.receipts[0]
	var delivery: PendingDelivery = commerce.pending_deliveries[0]
	_check(receipt.mode == PurchaseReceipt.Mode.TRADER_DELIVERY and receipt.delivery_fee == 100 and receipt.total_price == 280, "saved fee and purchase mode")
	_check(delivery.delivery_id == receipt.operation_id and delivery.item.key == &"large_shelf", "same stable operation and authored item")
	_check(delivery.ordered_day == 1 and delivery.delivery_day == 2 and delivery.quantity == 1 and not delivery.fulfilled, "waiting until next morning")
	var count: int = 0
	for operation: MoneyOperation in wallet.operations:
		if operation.operation_id == StringName(CommerceService.WALLET_PREFIX + String(receipt.operation_id)):
			count += 1
	_check(count == 1, "one matching wallet operation")
	var merchant: E_DistrictNpc = NpcActivityService.merchant()
	var player: Entity = ECS.world.get_parent().get_node("Entityes/Player") as Entity
	_check(CommerceService.home_delivery(player, merchant, delivery.item, 1, delivery.delivery_id) == CommerceService.Status.DUPLICATE, "restored replay rejected without payment")
	_check(wallet.balance == 720, "replay preserves balance")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var filename: String = ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(filename)
#endregion
