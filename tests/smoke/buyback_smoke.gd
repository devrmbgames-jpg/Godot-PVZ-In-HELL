extends "res://tests/smoke/npc_authored_people_smoke.gd"
## Два процесса: реальная продажа чужого содержимого и fresh контейнер без повторной выручки.

const BUYBACK_SLOT: String = "user://buyback_cold_smoke.pvzh"
const CONTAINER_ID: String = "buyback/cold/container"
const ITEM: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
var _shop: E_BuybackContainer
var _buyer: E_DistrictNpc
var _seller: Entity


#region Isolated native process lifecycle
func _make_world() -> World:
	return GameWorld.new()


func _save_path() -> String:
	return BUYBACK_SLOT


func _completion_prefix() -> String:
	return "Buyback smoke"


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup_slot()
	_create_world(RESTORE_CREATION_SEED if restoring else WRITE_SEED)
	for frame: int in 3:
		await get_tree().physics_frame
	if not _failed:
		if restoring:
			await _restore()
		else:
			await _write()
	_dispose_world()
	await get_tree().process_frame
	if restoring:
		_cleanup_slot()
	print(
		_completion_prefix(),
		" ",
		"restore" if restoring else "write",
		": ",
		"FAIL" if _failed else "PASS",
	)
	get_tree().quit(1 if _failed else 0)


func _create_world(world_seed: int) -> void:
	super._create_world(world_seed)
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_Wallet.new())
	session.add_component(C_Commerce.new())
	session.add_component(C_PackageLedger.new())
	session.add_component(C_LootDrops.new())
	_seller = Entity.new()
	_seller.id = "buyback/cold/actor"
	_seller.component_resources = [C_Inventory.new(), C_GrabControl.new()]
	_world.add_entity(_seller)
	_buyer = NpcPopulationQueries.body_for(&"npc/9")
	_check(
		DistrictPopulationService.set_placement(
			NpcPopulationQueries.person_for(&"npc/9"),
			_buyer,
			NpcRecord.Placement.STREET,
			&"buyback_smoke",
			false,
			Vector3(15, 0, 5),
		),
		"actual buyer available",
	)
	for person: NpcRecord in NpcPopulationQueries.current().people:
		NpcPopulationQueries.body_for(person.npc_id).set_physics_process(false)
	if "restore" not in OS.get_cmdline_user_args():
		_shop = (
			load("res://content/domains/commerce/entities/buyback_demon_container.tscn")
			as PackedScene
		).instantiate() as E_BuybackContainer
		_shop.id = CONTAINER_ID
		(_shop as Node as Node3D).position = Vector3(12, 0, 0)
		EntityCompositionFixture.register(_world, _shop)
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(120, 0.2, 120)
	collision.shape = box
	collision.position.y = -0.1
	floor.add_child(collision)
	_root.add_child(floor)
#endregion


#region Actual contents and cold exactly-once receipt
func _write() -> void:
	var shipment: PackageShipmentPlan = PackageShipmentRules.for_quantity(
		ITEM,
		1,
		SUPPLY.packing_profiles,
		WRITE_SEED,
		"buyback/cold/parcel",
		1,
	)
	_check(shipment != null, "native selected cargo fits authored shell")
	if shipment == null:
		return
	var parcel: E_Package = (load(shipment.scene_path()) as PackedScene).instantiate() as E_Package
	_check(
		ReceivingPackageFactory.configure_recipe(
			parcel,
			SUPPLY.packages[0],
			"buyback/cold/parcel",
			shipment,
		),
		"authored parcel recipe",
	)
	(parcel as Node as RigidBody3D).freeze = true
	(parcel as Node as Node3D).position = Vector3(5, 0.4, 0)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		_world,
		"buyback/cold/shell",
	)
	context.initial_fields[C_PackageContents as Script] = shipment.contents_fields()
	_check(EntityCompositionService.try_register(context), "real package registration")
	var arrival: PackageRegistrationRecord = PackageHistoryService.record_arrival(parcel, 1)
	_check(arrival != null, "real immutable arrival")
	(parcel.get_component(C_PackageState) as C_PackageState).opening = C_PackageState.Opening.OPENED
	var extracted: Array[Entity] = PackageContentsService.release(parcel, _seller)
	_check(extracted.size() == 1, "real extraction placed one free item")
	if extracted.size() != 1:
		return
	var item: Entity = extracted[0]
	var stack: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	_check(stack.source_history_id == arrival.history_id, "extracted provenance retained")
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(12, 1.2, 0)
	body.linear_velocity = Vector3.ZERO
	var receiving: C_Receiving = C_Receiving.new()
	receiving.batch_id = "buyback/cold"
	receiving.last_started_day = 1
	receiving.incoming_package_ids = [arrival.package_id]
	BuybackMarketService.accept_supply(
		_shop.get_component(C_Buyback) as C_Buyback,
		ReceivingSupplyCompleted.new(receiving, PackageQueries.ledger()),
	)
	for frame: int in 3:
		await get_tree().physics_frame
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	_check(offer.amount == 15, "one actual premium unit costs 150 percent of base")
	_check(
		BuybackTradeService.confirm(_seller, _buyer, offer) == BuybackTradeService.Status.COMMITTED,
		"committed physical sale",
	)
	_check(WalletService.current().balance == 15, "real wallet credited once")
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	_check(WorldSnapshotService.can_restore(snapshot, _root), "closed transaction snapshot")
	if not _failed:
		_check(AutosaveStore.write(snapshot, BUYBACK_SLOT) == OK, "isolated disk write")


func _restore() -> void:
	_check(_world.entity_id_registry.get(CONTAINER_ID) == null, "fresh process has no container")
	var snapshot: Dictionary = AutosaveStore.read(BUYBACK_SLOT)
	_check(WorldSnapshotService.can_restore(snapshot, _root), "cold prefab preflight")
	_check(WorldSnapshotService.restore(snapshot, _root), "cold snapshot restore")
	if _failed:
		return
	_shop = _world.entity_id_registry.get(CONTAINER_ID) as E_BuybackContainer
	_check(_shop != null, "native prefab reconstructed by saved stable ID")
	var state: C_Buyback = _shop.get_component(C_Buyback) as C_Buyback
	_check(GameTimeQueries.current().world_seed == WRITE_SEED, "saved clock replaces creation seed")
	_check(
		state.premium_spent_keys == PackedStringArray(["toy_block"]),
		"premium cap survives process",
	)
	var sales: Array[BuybackSale] = CommerceService.current().buyback_sales
	_check(
		sales.size() == 1 and WalletService.current().balance == 15,
		"one settled historical sale",
	)
	var sale: BuybackSale = sales[0]
	_check(
		sale.items[0].source_history_id
		== PackageHistoryService.record_for("buyback/cold/parcel").history_id,
		"foreign source history survives removal and cold load",
	)
	_check(not _world.entity_id_registry.has(sale.items[0].entity_id), "sold body cannot resurrect")
	var repeated: BuybackQuote = BuybackQuote.new()
	repeated.operation_id = sale.operation_id
	repeated.signature = sale.signature
	repeated.container_reference = weakref(_shop)
	repeated.state = state
	_check(
		BuybackTradeService.confirm(_seller, _buyer, repeated)
		== BuybackTradeService.Status.DUPLICATE,
		"cold retry remains duplicate",
	)
	_check(WalletService.current().balance == 15, "cold retry has no second credit")
	var item: Entity = (load(ITEM.world_pickup_scene) as PackedScene).instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(12, 1.2, 0)
	for frame: int in 3:
		await get_tree().physics_frame
	var ordinary: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	_check(
		ordinary.items.size() == 1 and ordinary.items[0].premium_quantity == 0,
		"next unit is ordinary",
	)
	_check(ordinary.amount >= 3 and ordinary.amount <= 7, "same saved daily price")
	_check(
		BuybackTradeService.confirm(_seller, _buyer, ordinary)
		== BuybackTradeService.Status.COMMITTED,
		"next ordinary physical sale",
	)
	_check(WalletService.current().balance == 15 + ordinary.amount, "only ordinary second income")
#endregion
