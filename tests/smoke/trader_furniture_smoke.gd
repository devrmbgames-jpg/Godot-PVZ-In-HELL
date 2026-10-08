extends Node
## Проверяет оплаченную физическую мебель торговца и утреннюю доставку в основной сцене.

var _level: Node


func _ready() -> void:
	_run.call_deferred()


## Проверяет физическую выдачу и утреннее исполнение оплаченной мебели без повторной оплаты.
func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	(actor as Node).set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.EVENING
	var wallet: C_Wallet = WalletService.current()
	wallet.balance = 1000
	var trader: Entity = ECS.world.query.with_all([C_Trader]).execute_one() as Entity
	assert(trader != null)
	var item: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_large_shelf.tres") as DEF_InventoryItem
	assert(CommerceService.purchase(actor, trader, item, 1, &"smoke/pickup") == CommerceService.Status.COMMITTED, "Actual trader pickup zone must fit a supported large shelf")

	var shelf: RigidBody3D = _goods("purchase/smoke/pickup") as Node as RigidBody3D
	assert(shelf != null and shelf.mass == 75.0)
	assert(shelf.global_position.y > 0.0 and shelf.global_position.y < 5.0)
	assert((shelf as Node as Entity).has_component(C_Anchorable))
	assert(CommerceService.home_delivery(actor, trader, item, 1, &"smoke/home") == CommerceService.Status.COMMITTED)
	assert(wallet.balance == 610)
	cycle.day_index += 1
	cycle.phase = C_DayCycle.Phase.MORNING

	var zone: Entity = ECS.world.query.with_all([C_OrderReceiving]).execute_one() as Entity
	assert(zone != null)
	assert(OrderDeliveryService.fulfill_one(zone, zone.get_component(C_OrderReceiving) as C_OrderReceiving, CommerceService.current(), cycle.day_index), "Actual home receiving area must fit the ordered shelf")
	assert(_goods("order/smoke/home") != null)
	assert(not OrderDeliveryService.fulfill_one(zone, zone.get_component(C_OrderReceiving) as C_OrderReceiving, CommerceService.current(), cycle.day_index))
	assert(wallet.operations.size() == 2)
	ECS.world.purge(false)
	_level.free()
	ECS.world = null
	await get_tree().process_frame
	print("Trader furniture actual main pickup paid home delivery smoke PASS")
	get_tree().quit.call_deferred()


func _goods(key: String) -> Entity:
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == key:
			return entity
	return null
