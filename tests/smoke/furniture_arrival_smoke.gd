extends Node
## Два процесса полного района: занятая площадка мебели, оплаченный остаток и физическая выдача после restore.

const SAVE_PATH: String = "user://furniture_arrival_smoke.pvzh"
const MAX_RECEIVING_FRAMES: int = 900
var _failed: bool = false

#region Полный район и оплаченная мебель
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
		_check(WorldSnapshotService.valid(snapshot, level), "blocked full snapshot validates")
		_check(WorldSnapshotService.restore(snapshot, level), "blocked order restores in new process")
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not _failed:
			_restore_and_issue(level)
		_cleanup()
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowService.current().visits.size() == 5:
				break
		level.set_physics_process(false)
		_check(CustomerFlowService.current().visits.size() == 5, "real receiving batch ready")
		if not _failed:
			await _buy_and_block(level)
	print("Furniture arrival smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _buy_and_block(level: Node3D) -> void:
	var player: Entity = level.get_node("Entityes/Player") as Entity
	var merchant: E_DistrictNpc = NpcActivityService.merchant()
	var zone: Entity = level.get_node("Entityes/OrderReceiving") as Entity
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	var marker: Marker3D = level.get("furniture_delivery_anchor") as Marker3D
	_check(marker != null and zone.get_node(state.furniture_anchor_path) == marker, "export resolves authored furniture marker")
	if _failed:
		return

	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	WalletService.current().balance = 1000
	var panel: CommercePanel = CommercePanelService.open(player, merchant)
	_check(panel != null, "day shop opens")
	if panel == null:
		return
	var shelf: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_large_shelf.tres") as DEF_InventoryItem
	panel._buy(shelf)
	panel._purchase_dialog.custom_action.emit(&"delivery")
	panel.close_panel()
	await get_tree().process_frame
	var commerce: C_Commerce = CommerceService.current()
	_check(commerce.pending_deliveries.size() == 1 and WalletService.current().balance == 720, "paid furniture order")
	if _failed:
		return

	var obstacle: StaticBody3D = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(12, 4, 9)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.position = marker.global_position + Vector3(0, 2, 0)
	add_child(obstacle)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not OrderDeliveryService.fulfill_one(zone, state, commerce, 1), "order waits until next morning")
	_check(not OrderDeliveryService.fulfill_one(zone, state, commerce, 2), "all authored candidates blocked")
	_check(state.blocked and not commerce.pending_deliveries[0].fulfilled, "blocked order stays unpaid again and unfulfilled")
	var snapshot: Dictionary = WorldSnapshotService.capture(level, 2)
	_check(WorldSnapshotService.valid(snapshot, level), "blocked next-morning snapshot validates")
	_check(AutosaveStore.write(snapshot, SAVE_PATH) == OK, "blocked order saved to own slot")

func _restore_and_issue(level: Node3D) -> void:
	var commerce: C_Commerce = CommerceService.current()
	var zone: Entity = level.get_node("Entityes/OrderReceiving") as Entity
	var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
	_check(state.retry_remaining == 0.0 and state.reservations.is_empty() and not state.identity_index_ready, "transient placement caches reset")
	_check(commerce.pending_deliveries.size() == 1, "one restored furniture order")
	if _failed:
		return
	var order: PendingDelivery = commerce.pending_deliveries[0]
	_check(not order.fulfilled and order.delivery_day == 2, "pending order kept next morning")
	_check(OrderDeliveryService.fulfill_one(zone, state, commerce, 2), "real authored area has safe supported candidate")
	var goods: Entity = _goods(OrderDeliveryService.key_for(order))
	_check(goods != null, "physical shelf exists")
	if goods == null:
		return
	_check((goods as Node as RigidBody3D).mass == 75.0 and not (goods as Node as RigidBody3D).freeze, "real massive movable furniture")
	_check(goods.has_component(C_Grabbable) and not goods.has_component(C_PlayerAnchored), "delivery does not install furniture")
	_check(WalletService.current().balance == 720 and CommerceService.current().receipts.size() == 1, "fulfillment never repays")
	_check(not OrderDeliveryService.fulfill_one(zone, state, commerce, 2), "repeat does not respawn")
	var issued: Dictionary = WorldSnapshotService.capture(level, 2)
	_check(AutosaveStore.write(issued, SAVE_PATH) == OK, "issued physical result saved")
	var saved: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(WorldSnapshotService.restore(saved, level), "issued result restores")
	_check(WorldSnapshotService.restore(saved, level), "repeated restore stays idempotent")
	_check(not OrderDeliveryService.fulfill_one(zone, state, CommerceService.current(), 3), "later morning does not recreate delivered furniture")
	var count: int = 0
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == OrderDeliveryService.key_for(order):
			count += 1
	_check(count == 1 and WalletService.current().balance == 720, "one physical identity and one payment after reload")

func _goods(key: String) -> Entity:
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == key:
			return entity
	return null

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
