extends "res://tests/gut/test_npc_life_cycle.gd"
## Авторский покупатель, фактический cargo, закрытый snapshot и реальные callbacks сделки.

const RECEIVING_SCENE: PackedScene = preload(
	"res://content/domains/packages/entities/receiving_zone.tscn"
)
const BUYBACK_SCENE: PackedScene = preload(
	"res://content/domains/commerce/entities/buyback_demon_container.tscn"
)
const BUYBACK_ITEM: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
var _shop: E_BuybackContainer
var _buyer: E_DistrictNpc
var _seller: Entity
var _market: C_Buyback
var _money: C_Wallet


#region Native integrated fixture
func before_each() -> void:
	super.before_each()
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_Wallet.new())
	session.add_component(C_Commerce.new())
	session.add_component(C_PackageLedger.new())
	_money = WalletService.current()
	_seller = Entity.new()
	_seller.component_resources = [C_GrabControl.new(), C_Inventory.new()]
	_world.add_entity(_seller)
	_buyer = NpcPopulationQueries.body_for(&"npc/9")
	assert_true(
		DistrictPopulationService.set_placement(
			NpcPopulationQueries.person_for(&"npc/9"),
			_buyer,
			NpcRecord.Placement.STREET,
			&"buyback_fixture",
			false,
			Vector3(15, 0, 5),
		)
	)
	_shop = BUYBACK_SCENE.instantiate() as E_BuybackContainer
	(_shop as Node as Node3D).position = Vector3(12, 0, 0)
	EntityCompositionFixture.register(_world, _shop)
	_market = _shop.get_component(C_Buyback) as C_Buyback
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(120, 0.2, 120)
	collision.shape = box
	collision.position.y = -0.1
	floor.add_child(collision)
	_root.add_child(floor)
	_world.add_observer(O_BuybackMarket.new())
	_world.add_observer(O_GameplayPanelRequest.new())
	await get_tree().physics_frame


func after_each() -> void:
	super.after_each()
	await get_tree().process_frame


func _arrived_cargo(
	package_id: String = "buyback/actual/toy", with_history: bool = true, quantity: int = 1,
) -> E_Package:
	var shipment: PackageShipmentPlan = PackageShipmentRules.for_quantity(
		BUYBACK_ITEM,
		quantity,
		SUPPLY.packing_profiles,
		17,
		"buyback/provenance",
		1,
	)
	assert_not_null(shipment)
	var parcel: E_Package = (load(shipment.scene_path()) as PackedScene).instantiate() as E_Package
	assert_true(
		ReceivingPackageFactory.configure_recipe(
			parcel,
			SUPPLY.packages[0],
			package_id,
			shipment,
		)
	)
	(parcel as Node as RigidBody3D).freeze = true
	(parcel as Node as Node3D).position = Vector3(5, 0.4, 0)
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		parcel,
		_world,
		package_id + "/shell",
	)
	context.initial_fields[C_PackageContents as Script] = shipment.contents_fields()
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	assert_true(plan.valid())
	assert_true(EntityCompositionService.register_plan(context, plan))
	# Fixture начинается с открытой оболочки; извлечение и placement исполняются production owners.
	(parcel.get_component(C_PackageState) as C_PackageState).opening = C_PackageState.Opening.OPENED
	if not with_history:
		return parcel
	assert_not_null(PackageHistoryService.record_arrival(parcel, 1))
	var receiving: C_Receiving = C_Receiving.new()
	receiving.batch_id = "buyback/actual"
	receiving.last_started_day = 1
	receiving.incoming_package_ids = [package_id]
	BuybackMarketService.accept_supply(
		_market,
		ReceivingSupplyCompleted.new(receiving, PackageQueries.ledger()),
	)
	return parcel


func _free_cargo(entity_id: String = "") -> Entity:
	var prefab: PackedScene = load(BUYBACK_ITEM.world_pickup_scene) as PackedScene
	var item: Entity = prefab.instantiate() as Entity
	item.id = entity_id
	EntityCompositionFixture.register(_world, item)
	(item.get_component(C_InventoryItem) as C_InventoryItem).quantity = 1
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(12, 1.2, 0)
	return item


func _physics_settled() -> void:
	for frame: int in 3:
		await get_tree().physics_frame
	await get_tree().process_frame
#endregion


#region Persistence and reentrant operations
func test_real_extraction_sale_disk_restore_keeps_provenance_and_premium_spent() -> void:
	var parcel: E_Package = _arrived_cargo()
	var history: String = (parcel.get_component(C_Package) as C_Package).history_id
	var extracted: Array[Entity] = PackageContentsService.release(parcel, _seller)
	assert_eq(extracted.size(), 1)
	var item: Entity = extracted[0]
	var stack: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	assert_eq(stack.source_package_id, "buyback/actual/toy")
	assert_eq(stack.source_history_id, history)
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(12, 1.2, 0)
	body.linear_velocity = Vector3.ZERO
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(offer.amount, 15)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.COMMITTED,
	)
	_world.flush_command_buffers()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	_market = _shop.get_component(C_Buyback) as C_Buyback
	_money = WalletService.current()
	assert_eq(_market.premium_spent_keys, PackedStringArray(["toy_block"]))
	assert_eq(_money.balance, 15)
	var sales: Array[BuybackSale] = CommerceService.current().buyback_sales
	assert_eq(sales.size(), 1)
	assert_eq(sales[0].items[0].source_history_id, history)
	assert_eq(PackageHistoryService.record_for("buyback/actual/toy").history_id, history)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.DUPLICATE,
	)
	var terminal: TerminalPanel = TerminalPanel.new()
	var money_entries: PackedStringArray = terminal.call("_transaction_entries")
	assert_true(money_entries[1].contains("+15"))
	assert_true(money_entries[1].contains("Скупка у жителя"))
	terminal.free()
	var saved_money: int = _money.balance
	_free_cargo()
	await _physics_settled()
	var next: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(next.items[0].premium_quantity, 0)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, next),
		BuybackTradeService.Status.COMMITTED,
	)
	assert_eq(WalletService.current().balance, saved_money + next.amount)


func test_reservation_blocks_other_consumers_and_partial_snapshot_before_payment() -> void:
	_arrived_cargo()
	var item: Entity = _free_cargo()
	await _physics_settled()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	var callbacks: Array[int] = [0]
	item.relationship_added.connect(
		func(_source: Entity, link: Relationship) -> void:
			if not link.relation is R_BuybackReserved:
				return
			callbacks[0] += 1
			assert_false(InventoryService.can_transfer(item, _seller))
			assert_true(WorldSnapshotService.capture(_root, 1).is_empty())
			assert_false(WorldSnapshotService.can_restore(snapshot, _root))
			assert_eq(
				BuybackTradeService.confirm(_seller, _buyer, offer),
				BuybackTradeService.Status.UNAVAILABLE,
			)
			# Native callback меняет UI object, но принятая сделка уже владеет собственной копией.
			offer.operation_id = &"callback/rewritten"
			offer.items.clear(),
	)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.COMMITTED,
	)
	assert_eq(callbacks[0], 1)
	assert_eq(_money.balance, 15)
	assert_ne(CommerceService.current().buyback_sales[0].operation_id, &"callback/rewritten")
	assert_eq(CommerceService.current().buyback_sales[0].items.size(), 1)


func test_phase_changed_from_reservation_callback_cancels_without_payment() -> void:
	_arrived_cargo()
	var item: Entity = _free_cargo()
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	item.relationship_added.connect(
		func(_source: Entity, link: Relationship) -> void:
			if link.relation is R_BuybackReserved:
				DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY,
	)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.UNAVAILABLE,
	)
	assert_eq(_money.balance, 0)
	assert_true(_world.entity_to_archetype.has(item))
	assert_true(CommerceService.current().buyback_sales.is_empty())
	assert_true(item.get_relationships(Relationship.new(R_BuybackReserved.new())).is_empty())


func test_death_and_actual_return_cannot_refill_old_day_or_change_price() -> void:
	_arrived_cargo()
	_free_cargo()
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.COMMITTED,
	)
	_world.flush_command_buffers()
	var before: Variant = SaveDataCodec.component_data(_market)
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/9")
	_kill(person)
	assert_eq(SaveDataCodec.component_data(_market), before)
	assert_false(BuybackTradeService.quote(_seller, _buyer).reason.is_empty())
	_morning(3)
	assert_eq(person.death_day, 0)
	assert_eq(person.deaths[0].returned_day, 3)
	assert_eq(SaveDataCodec.component_data(_market), before)
	assert_true(
		DistrictPopulationService.set_placement(
			person,
			_buyer,
			NpcRecord.Placement.STREET,
			&"buyback_return",
			false,
			Vector3(15, 0, 5),
		)
	)
	assert_eq(BuybackTradeService.quote(_seller, _buyer).reason, "Жду поставку")
#endregion


#region Truck exclusivity through synchronous native callbacks
func _truck_zone() -> E_ReceivingZone:
	var zone: E_ReceivingZone = RECEIVING_SCENE.instantiate() as E_ReceivingZone
	var parking: Marker3D = Marker3D.new()
	parking.position = Vector3(-20, 0, 0)
	_root.add_child(parking)
	zone.truck_parking = parking
	zone.package_parent = _root
	EntityCompositionFixture.register(_world, zone)
	(zone.get_component(C_Receiving) as C_Receiving).batch_id = "truck/exclusivity"
	assert_not_null(zone.ensure_truck())
	return zone


func test_truck_callback_cannot_sell_and_buyback_callback_cannot_dispatch() -> void:
	_arrived_cargo()
	var item: Entity = _free_cargo()
	var zone: E_ReceivingZone = _truck_zone()
	await _physics_settled()
	assert_true(TruckCargoService.commit(zone, DayPhaseQueries.current()), "Empty truck can commit")
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	item.relationship_added.connect(
		func(_source: Entity, link: Relationship) -> void:
			if link.relation is R_BuybackReserved:
				assert_false(TruckCargoService.commit(zone, DayPhaseQueries.current())),
	)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.COMMITTED,
	)
	assert_eq(_money.balance, 15)
	# A real truck cargo removal callback must also see buyback closed for its full manifest.
	_free_cargo()
	var cargo: Entity = _free_cargo()
	var truck: E_MorningTruck = zone.get_truck()
	(cargo as Node as Node3D).global_position = truck.cargo_slots[0].global_position
	await _physics_settled()
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	receiving.cargo_batch_id = ""
	var callbacks: Array[int] = [0]
	_world.entity_removed.connect(
		func(removed: Entity) -> void:
			if removed == cargo:
				callbacks[0] += 1
				var blocked: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
				assert_eq(blocked.reason, "Дождитесь завершения отгрузки")
				assert_true(blocked.operation_id.is_empty()),
	)
	assert_true(TruckCargoService.commit(zone, DayPhaseQueries.current()))
	assert_eq(callbacks[0], 1)
	assert_eq(CommerceService.current().buyback_sales.size(), 1)
#endregion


#region Corrupt snapshots, native confirmation and completed receiving
func _saved_fields(snapshot: Dictionary, script: Script) -> Dictionary:
	for record: Dictionary in snapshot.entities:
		for component: Dictionary in record.components:
			if component.type == script.resource_path:
				return component.fields as Dictionary
	return { }


func test_partial_or_inconsistent_receipt_rejects_before_live_mutation() -> void:
	_arrived_cargo()
	_free_cargo()
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer),
		BuybackTradeService.Status.COMMITTED,
	)
	_world.flush_command_buffers()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	var balance: int = WalletService.current().balance
	for defect: String in [
		"missing_field",
		"unsettled",
		"not_removed",
		"wrong_payment",
		"orphan_payment",
		"refilled_premium",
		"fictional_supply",
		"changed_price",
		"changed_signature",
	]:
		var invalid: Dictionary = snapshot.duplicate(true)
		var commerce: Dictionary = _saved_fields(invalid, C_Commerce)
		var market: Dictionary = _saved_fields(invalid, C_Buyback)
		var wallet: Dictionary = _saved_fields(invalid, C_Wallet)
		var sale: Dictionary = commerce.buyback_sales[0].fields as Dictionary
		match defect:
			"missing_field":
				sale.erase("signature")
			"unsettled":
				sale.set("settled", false)
			"not_removed":
				sale.items[0].fields.removed = false
			"wrong_payment":
				wallet.operations[-1].fields.amount += 1
			"orphan_payment":
				commerce.buyback_sales.clear()
			"refilled_premium":
				market.premium_spent_keys = PackedStringArray()
			"fictional_supply":
				market.source_package_ids = PackedStringArray(["never/arrived"])
			"changed_price":
				market.prices[0].fields.ordinary_price += 1
			"changed_signature":
				sale.signature += "/tampered"
		assert_false(WorldSnapshotService.can_restore(invalid, _root), defect)
		assert_false(WorldSnapshotService.restore(invalid, _root), defect)
		assert_eq(WalletService.current().balance, balance, defect)
		assert_eq(CommerceService.current().buyback_sales.size(), 1, defect)


func test_native_npc_action_opens_confirmation_and_changed_composition_needs_new_click() -> void:
	_arrived_cargo()
	_free_cargo()
	await _physics_settled()
	var actions: C_InteractionActionSet = (
		_buyer.get_component(C_InteractionActionSet) as C_InteractionActionSet
	)
	var action: DEF_BuybackAction = null
	for candidate: DEF_InteractionAction in actions.actions:
		if candidate is DEF_BuybackAction:
			action = candidate as DEF_BuybackAction
	assert_not_null(action)
	if action == null:
		return
	assert_true(action.is_available(_seller, _buyer, _buyer))
	action.execute(_seller, _buyer, _buyer)
	_world.flush_command_buffers()
	var panel: BuybackPanel = _seller.find_child("BuybackPanel", false, false) as BuybackPanel
	assert_not_null(panel)
	if panel == null:
		return
	var dialog: ConfirmationDialog = panel.get_node("Confirmation") as ConfirmationDialog
	assert_true(dialog.visible)
	assert_eq(InteractionControlFocus.current(_seller), InteractionControlFocus.Priority.MODAL)
	assert_eq(_money.balance, 0)
	var second: Entity = _free_cargo()
	(second as Node as Node3D).global_position.x = 13
	await _physics_settled()
	dialog.confirmed.emit()
	assert_eq(_money.balance, 0, "A changed quote only replaces the displayed offer")
	assert_false(panel.is_queued_for_deletion())
	assert_true(
		(panel.get_node("Confirmation/Contents/Summary") as Label).text.contains("изменились")
	)
	await get_tree().process_frame
	dialog.confirmed.emit()
	assert_eq(
		_money.balance,
		15 + BuybackMarketService.ensure_price(_market, BUYBACK_ITEM).ordinary_price,
	)
	assert_eq(CommerceService.current().buyback_sales.size(), 1)
	assert_true(panel.is_queued_for_deletion())
	assert_lt(InteractionControlFocus.current(_seller), InteractionControlFocus.Priority.MODAL)
	await get_tree().process_frame


func test_native_cancel_and_closing_phase_preserve_items_and_release_focus() -> void:
	_arrived_cargo()
	var item: Entity = _free_cargo()
	await _physics_settled()
	var panel: BuybackPanel = BuybackPanelFactory.open(_seller, _buyer)
	assert_not_null(panel)
	if panel == null:
		return
	(panel.get_node("Confirmation") as ConfirmationDialog).canceled.emit()
	assert_true(_world.entity_to_archetype.has(item))
	assert_eq(_money.balance, 0)
	assert_lt(InteractionControlFocus.current(_seller), InteractionControlFocus.Priority.MODAL)
	await get_tree().process_frame
	panel = BuybackPanelFactory.open(_seller, _buyer)
	assert_not_null(panel)
	if panel == null:
		return
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	var panel_reference: WeakRef = weakref(panel)
	await wait_until(
		func() -> bool:
			return panel_reference.get_ref() == null,
		1.0,
	)
	assert_false(is_instance_valid(panel))
	assert_eq(_money.balance, 0)
	assert_true(_world.entity_to_archetype.has(item))
	assert_lt(InteractionControlFocus.current(_seller), InteractionControlFocus.Priority.MODAL)
	await get_tree().process_frame


func test_real_receiving_opens_market_only_after_last_physical_arrival() -> void:
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_CustomerFlow.new())
	CustomerFlowQueries.current().schedule = load(
		"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
	) as DEF_CustomerSchedule
	var zone: E_ReceivingZone = RECEIVING_SCENE.instantiate() as E_ReceivingZone
	zone.supply = SUPPLY.duplicate() as DEF_Delivery
	zone.supply.maximum_batch_packages = 2
	# Pilot identities use resident_* keys; the default campaign supply uses customer_*.
	# Detached fixture parcels target the real pilot without changing those authored identities.
	zone.supply.packages = []
	for definition: DEF_Package in SUPPLY.packages:
		var copy: DEF_Package = definition.duplicate() as DEF_Package
		copy.recipient_id = _district.people[0].recipient_key
		zone.supply.packages.append(copy)
	zone.supply.order_catalog = [BUYBACK_ITEM]
	zone.package_parent = _root
	(zone as Node as Node3D).position = Vector3(-12, 0, 0)
	EntityCompositionFixture.register(_world, zone)
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	ReceivingDeliveryService.prepare_batch(zone.supply, receiving, 1)
	_world.flush_command_buffers()
	assert_eq(_market.price_day, 0)
	assert_eq(receiving.pending[0].package_keys.size(), 2)
	await _physics_settled()
	ReceivingDeliveryService.deliver_one(zone, receiving, 1)
	_world.flush_command_buffers()
	assert_eq(PackageQueries.ledger().records.size(), 1)
	assert_eq(_market.price_day, 0, "One actual arrival does not complete the BASE_SUPPLY")
	await _physics_settled()
	ReceivingDeliveryService.deliver_one(zone, receiving, 1)
	_world.flush_command_buffers()
	assert_true(receiving.pending.is_empty())
	assert_eq(PackageQueries.ledger().records.size(), 2)
	assert_eq(_market.price_day, 1)
	assert_eq(_market.source_package_ids.size(), 2)
	assert_between(_market.premium_item_keys.size(), 1, 2)
	assert_eq(DayPhaseQueries.current().phase, C_DayCycle.Phase.MORNING)
	var before: Dictionary = SaveDataCodec.component_data(_market)
	ReceivingDeliveryService.deliver_one(zone, receiving, 1)
	_world.flush_command_buffers()
	assert_eq(SaveDataCodec.component_data(_market), before)
#endregion


#region RV-001 exact endpoints after payment and RV-002 historical unknown provenance
func test_paid_removal_preserves_replacement_with_reused_id() -> void:
	_arrived_cargo()
	_free_cargo()
	var another: Entity = _free_cargo()
	(another as Node as Node3D).global_position.x = 13
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(offer.items.size(), 2)
	var first_id: String = offer.items[0].entity_id
	var second_id: String = offer.items[1].entity_id
	var second_reference: WeakRef = weakref(_world.entity_id_registry.get(second_id))
	var replacements: Array[WeakRef] = []
	_world.entity_removed.connect(func(removed: Entity) -> void:
		if removed.id != first_id:
			return
		assert_eq(
			BuybackTradeService.confirm(_seller, _buyer, offer),
			BuybackTradeService.Status.UNAVAILABLE,
			"A paid transaction still retiring items is not a completed duplicate",
		)
		_world.remove_entity(second_reference.get_ref() as Entity)
		replacements.append(weakref(_free_cargo(second_id)))
	)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer), BuybackTradeService.Status.COMMITTED,
	)
	assert_eq(replacements.size(), 1)
	var replacement: Entity = replacements[0].get_ref() as Entity
	assert_true(
		_world.entity_to_archetype.has(replacement), "Replacement was never accepted or reserved",
	)
	assert_eq(_world.entity_id_registry.get(second_id), replacement)
	assert_eq(_money.balance, offer.amount)
	assert_eq(_money.operations.size(), 1)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer), BuybackTradeService.Status.DUPLICATE,
	)
	assert_true(_world.entity_to_archetype.has(replacement))
	assert_eq(_money.operations.size(), 1)


func test_paid_removal_finishes_captured_world_after_current_world_switch() -> void:
	_arrived_cargo()
	_free_cargo()
	var another: Entity = _free_cargo()
	(another as Node as Node3D).global_position.x = 13
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(offer.items.size(), 2)
	var first_id: String = offer.items[0].entity_id
	var alternate_world: World = World.new()
	add_child(alternate_world)
	var alternate_reference: WeakRef = weakref(alternate_world)
	_world.entity_removed.connect(func(removed: Entity) -> void:
		if removed.id == first_id:
			ECS.world = alternate_reference.get_ref() as World
	)
	var result: BuybackTradeService.Status = BuybackTradeService.confirm(_seller, _buyer, offer)
	assert_eq(ECS.world, alternate_world)
	assert_true(alternate_world.entities.is_empty(), "The new World is untouched")
	ECS.world = _world
	assert_eq(result, BuybackTradeService.Status.COMMITTED)
	for line: BuybackSaleItem in offer.items:
		assert_false(_world.entity_id_registry.has(line.entity_id), line.entity_id)
	assert_eq(_money.operations.size(), 1)
	assert_eq(_money.balance, offer.amount)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer), BuybackTradeService.Status.DUPLICATE,
	)
	_world.flush_command_buffers()
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 1), _root))
	alternate_world.purge(false)
	alternate_world.free()


func test_late_shell_registration_keeps_unknown_extraction_and_sale_provenance() -> void:
	var parcel: E_Package = _arrived_cargo("buyback/untracked/toy", false, 2)
	var extracted: Array[Entity] = PackageContentsService.release(parcel, _seller)
	assert_eq(extracted.size(), 2)
	if extracted.size() != 2:
		return
	_arrived_cargo()
	var item: Entity = extracted[0]
	var survivor: Entity = extracted[1]
	for entry: Entity in extracted:
		var stack: C_InventoryItem = entry.get_component(C_InventoryItem) as C_InventoryItem
		assert_eq(stack.source_package_id, "buyback/untracked/toy")
		assert_true(stack.source_history_id.is_empty())
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(12, 1.2, 0)
	body.linear_velocity = Vector3.ZERO
	await _physics_settled()
	var offer: BuybackQuote = BuybackTradeService.quote(_seller, _buyer)
	assert_eq(offer.items.size(), 1)
	assert_eq(
		BuybackTradeService.confirm(_seller, _buyer, offer), BuybackTradeService.Status.COMMITTED,
	)
	_world.flush_command_buffers()
	var sale: BuybackSale = CommerceService.current().buyback_sales[0]
	var signature: String = sale.signature
	var before: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(before, _root))
	assert_eq(
		PackageRegistrationService.register_package(parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	assert_false((parcel.get_component(C_Package) as C_Package).history_id.is_empty())
	var survivor_id: String = survivor.id
	var survivor_stack: C_InventoryItem = survivor.get_component(C_InventoryItem) as C_InventoryItem
	assert_true(survivor_stack.source_history_id.is_empty())
	assert_true(sale.items[0].source_history_id.is_empty())
	assert_eq(sale.signature, signature)
	_world.flush_command_buffers()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(
		WorldSnapshotService.can_restore(snapshot, _root),
		"Late arrival cannot rewrite earlier facts",
	)
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	var restored: Entity = _world.entity_id_registry.get(survivor_id) as Entity
	assert_not_null(restored)
	var restored_stack: C_InventoryItem = restored.get_component(C_InventoryItem) as C_InventoryItem
	assert_true(restored_stack.source_history_id.is_empty())
	assert_eq(CommerceService.current().buyback_sales[0].signature, signature)
	assert_eq(WalletService.current().operations.size(), 1)
	assert_eq(WalletService.current().balance, offer.amount)
#endregion
