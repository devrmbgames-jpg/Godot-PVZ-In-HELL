extends GutTest
## Native контейнер, штатный wallet и резерв доказывают явную, повторяемую продажу.

const CONTAINER: PackedScene = preload(
	"res://content/domains/commerce/entities/buyback_demon_container.tscn"
)
const MED: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_med.tres"
)
const HOLY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_holy_artifact.tres"
)
var _world: World
var _session: Entity
var _actor: Entity
var _trader: Entity
var _container: E_BuybackContainer
var _state: C_Buyback
var _wallet: C_Wallet
var _commerce: C_Commerce


#region Native fixture
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [
		C_DayCycle.new(),
		C_Wallet.new(),
		C_Commerce.new(),
		C_PackageLedger.new(),
	]
	_world.add_entity(_session)
	_wallet = WalletService.current()
	_commerce = CommerceService.current()
	_actor = Entity.new()
	_world.add_entity(_actor)
	_trader = Entity.new()
	var identity: C_NpcIdentity = C_NpcIdentity.new()
	identity.npc_id = &"npc/9"
	_trader.component_resources = [identity]
	_world.add_entity(_trader)
	_container = CONTAINER.instantiate() as E_BuybackContainer
	EntityCompositionFixture.register(_world, _container)
	_state = _container.get_component(C_Buyback) as C_Buyback
	var receiving: C_Receiving = C_Receiving.new()
	receiving.batch_id = "buyback/native/1"
	receiving.last_started_day = 1
	receiving.incoming_package_ids = ["actual/med"]
	var arrival: PackageRegistrationRecord = PackageRegistrationRecord.new()
	arrival.package_id = "actual/med"
	arrival.received_day = 1
	arrival.ordered_item = MED
	arrival.ordered_quantity = 1
	var ledger: C_PackageLedger = _session.get_component(C_PackageLedger) as C_PackageLedger
	ledger.records.append(arrival)
	BuybackMarketService.accept_supply(_state, ReceivingSupplyCompleted.new(receiving, ledger))


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	await get_tree().process_frame


func _item(definition: DEF_InventoryItem = MED) -> Entity:
	var packed: PackedScene = load(definition.world_pickup_scene) as PackedScene
	var item: Entity = packed.instantiate() as Entity
	EntityCompositionFixture.register(_world, item)
	(item.get_component(C_InventoryItem) as C_InventoryItem).quantity = 1
	var body: RigidBody3D = item as Node as RigidBody3D
	body.gravity_scale = 0.0
	body.global_position = Vector3(0, 1.2, 0)
	return item


func _settle() -> void:
	for frame: int in 3:
		await get_tree().physics_frame
	await get_tree().process_frame
#endregion


#region Explicit sales and stale quotes
func test_overlap_and_quote_leave_real_item_and_wallet_unchanged() -> void:
	var item: Entity = _item()
	await _settle()
	var offer: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	assert_eq(offer.items.size(), 1)
	assert_eq(offer.amount, 90)
	assert_eq(_wallet.balance, 0)
	assert_true(_world.entity_to_archetype.has(item))
	assert_true(_commerce.buyback_sales.is_empty())


func test_confirm_pays_once_and_next_item_gets_only_ordinary_price() -> void:
	var item: Entity = _item()
	await _settle()
	var offer: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, offer),
		BuybackTradeService.Status.COMMITTED,
	)
	assert_eq(_wallet.balance, 90)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_wallet.operations[0].reason, MoneyOperation.Reason.NPC_BUYBACK)
	assert_false(_world.entity_to_archetype.has(item))
	assert_eq(_commerce.buyback_sales.size(), 1)
	assert_true(_commerce.buyback_sales[0].settled)
	assert_true(_commerce.buyback_sales[0].items[0].removed)
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, offer),
		BuybackTradeService.Status.DUPLICATE,
	)
	assert_eq(_wallet.balance, 90)
	_item()
	await _settle()
	var next: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	assert_eq(next.items[0].premium_quantity, 0)
	assert_eq(next.amount, _state.prices[0].ordinary_price)
	assert_between(next.amount, 18, 42)


func test_same_frame_move_or_new_item_requires_another_confirmation() -> void:
	var item: Entity = _item()
	await _settle()
	var offer: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	(item as Node as RigidBody3D).global_position = Vector3(10, 1, 0)
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, offer),
		BuybackTradeService.Status.CHANGED,
	)
	assert_eq(_wallet.balance, 0)
	assert_true(_commerce.buyback_sales.is_empty())
	(item as Node as RigidBody3D).global_position = Vector3(0, 1.2, 0)
	var original: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	var second: Entity = _item()
	(second as Node as RigidBody3D).global_position.x = 1
	await _settle()
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, original),
		BuybackTradeService.Status.CHANGED,
	)
	assert_eq(_wallet.balance, 0)


func test_held_holy_and_partial_outside_items_are_refused() -> void:
	var item: Entity = _item()
	item.add_relationship(Relationship.new(R_HeldBy.new(), _actor))
	var holy: Entity = _item(HOLY)
	(holy as Node as RigidBody3D).global_position.x = 1
	var partial: Entity = _item()
	(partial as Node as RigidBody3D).global_position.x = -1
	await _settle()
	# Кеш Area ещё содержит тело; полная текущая форма уже пересекает границу приёмки.
	(partial as Node as RigidBody3D).global_position.x = 1.94
	var offer: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	assert_true(offer.items.is_empty())
	assert_eq(offer.rejected.size(), 3)
	assert_eq(offer.amount, 0)
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, offer),
		BuybackTradeService.Status.UNAVAILABLE,
	)
	assert_eq(_wallet.balance, 0)
	assert_true(_world.entity_to_archetype.has(holy))


func test_overflow_and_phase_change_do_not_remove_or_spend_premium() -> void:
	var item: Entity = _item()
	await _settle()
	var offer: BuybackQuote = BuybackTradeService.quote(_actor, _trader)
	_wallet.balance = WalletService.MAX_AMOUNT
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, offer),
		BuybackTradeService.Status.CONFLICT,
	)
	assert_true(_world.entity_to_archetype.has(item))
	assert_true(_state.premium_spent_keys.is_empty())
	assert_true(_commerce.buyback_sales.is_empty())
	assert_true(item.get_relationships(Relationship.new(R_BuybackReserved.new())).is_empty())
	_wallet.balance = 0
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	assert_eq(
		BuybackTradeService.confirm(_actor, _trader, offer),
		BuybackTradeService.Status.UNAVAILABLE,
	)
	assert_eq(_wallet.balance, 0)
#endregion


#region Actual supply and immutable daily demand
func test_fact_uses_only_actual_arrivals_and_same_supply_does_not_refill() -> void:
	var receiving: C_Receiving = C_Receiving.new()
	receiving.batch_id = "buyback/native/1"
	receiving.last_started_day = 1
	receiving.incoming_package_ids = ["actual/med", "planned/missing", "wrong/day"]
	var ledger: C_PackageLedger = _session.get_component(C_PackageLedger) as C_PackageLedger
	var old: PackageRegistrationRecord = PackageRegistrationRecord.new()
	old.package_id = "wrong/day"
	old.received_day = 0
	old.ordered_item = HOLY
	old.ordered_quantity = 1
	ledger.records.append(old)
	var fact: ReceivingSupplyCompleted = ReceivingSupplyCompleted.new(receiving, ledger)
	assert_eq(fact.package_ids, PackedStringArray(["actual/med"]))
	assert_eq(fact.items, [MED])
	_state.premium_spent_keys.append("med")
	var previous_price: int = _state.prices[0].ordinary_price
	BuybackMarketService.accept_supply(_state, fact)
	assert_eq(_state.premium_spent_keys, PackedStringArray(["med"]))
	assert_eq(_state.prices[0].ordinary_price, previous_price)


func test_closed_record_codec_rejects_missing_transaction_fields() -> void:
	for record: Resource in [BuybackSale.new(), BuybackSaleItem.new(), BuybackItemPrice.new()]:
		var encoded: Dictionary = SaveDataCodec.encode(record) as Dictionary
		assert_not_null(SaveDataCodec.decode(encoded))
		var fields: Dictionary = encoded.fields as Dictionary
		fields.erase(fields.keys()[0])
		assert_null(SaveDataCodec.decode(encoded))
#endregion
