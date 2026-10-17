extends Node
## Два headless процесса: отдельный кошелёк/терминал, частичная выдача и восстановление без ПВЗ.

const SLOT: String = "user://angel_furniture_cold_smoke.pvzh"
const TERMINAL_ID: String = "angel/cold/terminal"
const ORIGINAL_PRICE: int = 180
const ORIGINAL_HINT: String = "Площадка мебели у дома Плачущего ангела"
var _root: Node3D
var _world: World
var _actor: Entity
var _terminal: E_Terminal
var _failed: bool = false


#region Isolated process lifecycle
func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	_create_world()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if restoring:
		await _restore()
	else:
		await _write()
	if is_instance_valid(_terminal):
		_terminal.close_panel()
	_world.purge(false)
	_root.free()
	ECS.world = null
	await get_tree().process_frame
	if restoring and FileAccess.file_exists(SLOT):
		DirAccess.remove_absolute(SLOT)
	print(
		"Angel furniture smoke ",
		"restore" if restoring else "write",
		": ",
		"FAIL" if _failed else "PASS",
	)
	get_tree().quit(1 if _failed else 0)


func _create_world() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_DayCycle.new(), C_Wallet.new()]
	_root.add_child(session)
	session.owner = _root
	FixturePlacedIdentity.assign(_root, session, &"session")
	EntityCompositionFixture.register(_world, session, false)
	_actor = Entity.new()
	_actor.component_resources = [C_Inventory.new(), C_GrabControl.new()]
	_root.add_child(_actor)
	_actor.owner = _root
	FixturePlacedIdentity.assign(_root, _actor, &"actor")
	EntityCompositionFixture.register(_world, _actor, false)
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60, 0.2, 60)
	collision.shape = box
	collision.position.y = -0.1
	floor.add_child(collision)
	_root.add_child(floor)
	var delivery: S_AngelOrderDelivery = S_AngelOrderDelivery.new()
	delivery.group = "ColdAngel"
	_world.add_system(delivery)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Angel furniture smoke: " + message)


func _tick() -> void:
	_world.process(2.0, "ColdAngel")
	_world.flush_command_buffers()
	await get_tree().physics_frame
#endregion


#region Frozen promises across actual process restart
func _write() -> void:
	if FileAccess.file_exists(SLOT):
		DirAccess.remove_absolute(SLOT)
	WalletService.current().balance = 2000
	_terminal = (
		load("res://content/domains/commerce/entities/angel_furniture_terminal.tscn") as PackedScene
	).instantiate() as E_Terminal
	_terminal.id = TERMINAL_ID
	(_terminal as Node as Node3D).position = Vector3(8, 0, 0)
	EntityCompositionFixture.register(_world, _terminal)
	var item: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_large_shelf.tres",
	) as DEF_InventoryItem
	for index: int in 3:
		var offer: AngelFurnitureQuote = AngelFurnitureService.quote(_actor, _terminal, item)
		_check(offer.reason.is_empty(), "native prepay compatible")
		_check(
			AngelFurnitureService.confirm(_actor, offer) == AngelFurnitureService.Status.COMMITTED,
			"payment accepted",
		)
	DayPhaseQueries.current().day_index = 2
	await _tick()
	await _tick()
	var orders: Array[AngelFurnitureOrder] = (
		_terminal.get_component(C_AngelOrders) as C_AngelOrders
	).orders
	_check(orders[0].issued and orders[1].issued and not orders[2].issued, "partial issuance")
	var moved: Entity = _world.get_entity_by_id(orders[0].output_id)
	(moved as Node as Node3D).global_position = Vector3(-10, 2, 8)
	_world.remove_entity(_world.get_entity_by_id(orders[1].output_id))
	await get_tree().process_frame
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	_check(WorldSnapshotService.can_restore(snapshot, _root), "partial snapshot preflight")
	_check(AutosaveStore.write(snapshot, SLOT) == OK, "isolated slot write")


func _restore() -> void:
	_check(_world.get_entity_by_id(TERMINAL_ID) == null, "fresh process has no terminal")
	_check(CommerceService.current() == null, "PVZ owner genuinely absent")
	var profile: DEF_AngelFurnitureShop = load(
		"res://content/domains/commerce/definitions/def_angel_furniture_prototype.tres",
	) as DEF_AngelFurnitureShop
	profile.catalog[0].market_price = 999
	profile.catalog = []
	profile.receiving_hint = "Changed catalog hint"
	var snapshot: Dictionary = AutosaveStore.read(SLOT)
	_check(WorldSnapshotService.can_restore(snapshot, _root), "cold native preflight")
	_check(WorldSnapshotService.restore(snapshot, _root), "cold restore")
	if _failed:
		return
	_terminal = _world.get_entity_by_id(TERMINAL_ID) as E_Terminal
	_check(_terminal != null, "native own terminal reconstructed")
	var state: C_AngelOrders = _terminal.get_component(C_AngelOrders) as C_AngelOrders
	_check(state.orders.size() == 3, "three independent promises")
	for record: AngelFurnitureOrder in state.orders:
		_check(record.total_price == ORIGINAL_PRICE and record.ready_day == 2, "price/day frozen")
		_check(record.receiving_hint == ORIGINAL_HINT, "home hint frozen")
	var repeated: AngelFurnitureQuote = AngelFurnitureQuote.new()
	repeated.world = weakref(_world)
	repeated.actor = weakref(_actor)
	repeated.terminal = weakref(_terminal)
	repeated.state = state
	repeated.order = state.orders[0].duplicate(false) as AngelFurnitureOrder
	_check(
		AngelFurnitureService.confirm(_actor, repeated) == AngelFurnitureService.Status.DUPLICATE,
		"historical duplicate without current catalog",
	)
	_terminal.open_for(_actor)
	_check(_terminal.is_open_for(_actor), "own native UI without PVZ")
	_terminal.close_panel()
	await _tick()
	_check(
		state.orders[0].received and state.orders[1].received,
		"moved/destroyed goods recognized",
	)
	_check(state.orders[2].issued, "remaining debt issued once")
	_check(
		_world.get_entity_by_id(state.orders[1].output_id) == null,
		"destroyed issued body stays absent",
	)
	var moved: Entity = _world.get_entity_by_id(state.orders[0].output_id)
	_check(
		(moved as Node as Node3D).global_position.distance_to(Vector3(-10, 2, 8)) < 0.2,
		"moved physical pose preserved",
	)
	var count: int = _world.entities.size()
	await _tick()
	_check(_world.entities.size() == count, "no repeated bodies")
	_check(WalletService.current().operations.size() == 3, "no repeated payments")
	_check(WalletService.current().balance == 2000 - 3 * ORIGINAL_PRICE, "historical balance")
	_check(
		WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 2), _root),
		"fulfilled snapshot remains valid",
	)
#endregion
