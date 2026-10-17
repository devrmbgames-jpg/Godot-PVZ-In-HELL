extends "res://tests/gut/test_buyback_lifecycle.gd"
## Actual Hag role, native goods, immediate payment/use and retained life/save boundaries.

const HAG_PROFILE: DEF_TraderProfile = preload(
	"res://content/domains/commerce/definitions/def_trader_hag_prototype.tres"
)


#region Actual authored role and customer
func _open_hag_shop() -> E_DistrictNpc:
	_hag_point()
	_money.balance = 1000
	DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
	return NpcPopulationQueries.body_for(&"npc/6")


func _owned(definition: DEF_InventoryItem) -> Entity:
	for item: Entity in InventoryService.items(_seller):
		if (item.get_component(C_InventoryItem) as C_InventoryItem).definition == definition:
			return item
	return null


func _enable_use() -> void:
	_world.add_observer(O_InventoryEffect.new())
	var health: C_Health = C_Health.new()
	health.value = 100.0
	health.current = 30.0
	_seller.add_component(health)
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = (
		load("res://content/domains/needs/definitions/def_hunger_default.tres") as DEF_HungerPolicy
	)
	hunger.value = 90.0
	_seller.add_component(hunger)
#endregion


#region Public assortment and actual effects
func test_authored_hag_gets_separate_evening_shop_without_changing_merchant_job() -> void:
	var hag: E_DistrictNpc = _open_hag_shop()
	assert_false(NpcPopulationQueries.person_for(&"npc/6").profile.merchant)
	var shop: C_Trader = hag.get_component(C_Trader) as C_Trader
	assert_not_null(shop)
	assert_same(shop.profile, HAG_PROFILE)
	assert_eq(shop.trader_key, HAG_PROFILE.key)
	assert_null(_buyer.get_component(C_Trader))
	assert_eq(
		TraderCatalogRules
		.catalog(shop)
		.map(
			func(item: DEF_InventoryItem) -> StringName:
				return item.key,
		),
		[&"med", &"healing_potion", &"cookie", &"meat_pie"],
	)
	var actions: C_InteractionActionSet = hag.get_component(C_InteractionActionSet)
	var trades: int = 0
	var buybacks: int = 0
	for action: DEF_InteractionAction in actions.actions:
		if action is DEF_TraderAction:
			trades += 1
			assert_true(action.is_available(_seller, hag, null))
			DayPhaseQueries.current().phase = C_DayCycle.Phase.MORNING
			assert_false(action.is_available(_seller, hag, null))
			DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
		if action is DEF_BuybackAction:
			buybacks += 1
	assert_eq(trades, 1)
	assert_eq(buybacks, 1)
	assert_false(HAG_PROFILE.home_delivery_enabled)
	assert_null(HAG_PROFILE.refusal_quest)


func test_cookie_and_meat_pie_have_distinct_purchase_prices_native_scenes_and_food_use() -> void:
	var hag: E_DistrictNpc = _open_hag_shop()
	_enable_use()
	var hunger: C_Hunger = _seller.get_component(C_Hunger) as C_Hunger
	for index: int in [2, 3]:
		var definition: DEF_InventoryItem = HAG_PROFILE.catalog[index]
		var balance: int = _money.balance
		var operation_id: StringName = StringName("hag/food/%d" % index)
		assert_eq(
			CommerceService.purchase(_seller, hag, definition, 1, operation_id),
			CommerceService.Status.COMMITTED,
		)
		assert_eq(_money.balance, balance - definition.market_price)
		var purchased: Entity = _owned(definition)
		assert_not_null(purchased)
		assert_false(purchased.id.is_empty())
		var before: float = hunger.value
		assert_true(InventoryService.use(_seller, purchased))
		assert_eq(hunger.value, before - definition.food_effect.hunger_relief)
		assert_null(_owned(definition))
		assert_eq(
			CommerceService.purchase(_seller, hag, definition, 1, operation_id),
			CommerceService.Status.DUPLICATE,
		)
		assert_null(_owned(definition))
	assert_ne(HAG_PROFILE.catalog[2].market_price, HAG_PROFILE.catalog[3].market_price)
	assert_ne(HAG_PROFILE.catalog[2].food_effect, HAG_PROFILE.catalog[3].food_effect)
	assert_ne(HAG_PROFILE.catalog[2].world_pickup_scene, HAG_PROFILE.catalog[3].world_pickup_scene)
	assert_eq(_money.operations.size(), 2)
	assert_true(CommerceService.current().pending_deliveries.is_empty())


func test_healing_potion_uses_existing_damage_receipt_without_poison_or_bomb_alias() -> void:
	var hag: E_DistrictNpc = _open_hag_shop()
	_enable_use()
	var potion: DEF_InventoryItem = HAG_PROFILE.catalog[1]
	assert_eq(potion.kind, DEF_InventoryItem.Kind.MED_ITEM)
	assert_eq(
		CommerceService.purchase(_seller, hag, potion, 1, &"hag/potion"),
		CommerceService.Status.COMMITTED,
	)
	var health: C_Health = _seller.get_component(C_Health) as C_Health
	assert_true(InventoryService.use(_seller, _owned(potion)))
	assert_eq(health.current, 30.0 + potion.healing)
	assert_null(_owned(potion))
	for key: String in ["toxin_flask", "fire_flask", "reagent_flask"]:
		var wrong: DEF_InventoryItem = load(
			"res://content/domains/inventory/definitions/def_item_%s.tres" % key,
		) as DEF_InventoryItem
		assert_eq(
			CommerceService.purchase(_seller, hag, wrong, 1, StringName(key)),
			CommerceService.Status.INVALID,
		)
	assert_eq(_money.operations.size(), 1)


func test_native_food_and_potion_prefabs_have_exact_stack_and_live_inventory_pickup() -> void:
	_open_hag_shop()
	for index: int in [1, 2, 3]:
		var definition: DEF_InventoryItem = HAG_PROFILE.catalog[index]
		var pickup: E_InventoryPickup = (
			(load(definition.world_pickup_scene) as PackedScene).instantiate() as E_InventoryPickup
		)
		(pickup as Node as RigidBody3D).gravity_scale = 0.0
		(pickup as Node as Node3D).position = Vector3(-15, 1, index)
		EntityCompositionFixture.register(_world, pickup)
		var stack: C_InventoryItem = pickup.get_component(C_InventoryItem) as C_InventoryItem
		assert_same(stack.definition, definition)
		assert_eq(stack.quantity, 1)
		assert_not_null((pickup.get_node("Collision") as CollisionShape3D).shape)
		var actions: C_InteractionActionSet = pickup.get_component(C_InteractionActionSet)
		assert_true(actions.actions[0].is_available(_seller, pickup, null))
		actions.actions[0].execute(_seller, pickup, null)
		assert_same(InventoryService.owner_for(pickup), _seller)
	assert_eq(InventoryService.items(_seller).size(), 3)
	assert_true(_money.operations.is_empty())
#endregion


#region Refusal, UI and persistent life
func test_open_panel_rechecks_phase_and_full_inventory_before_any_payment() -> void:
	var hag: E_DistrictNpc = _open_hag_shop()
	var panel: CommercePanel = CommercePanelFactory.open(_seller, hag)
	assert_not_null(panel)
	var offers: VBoxContainer = panel.get_node("Root/Center/Panel/Content/OffersScroll/Offers")
	assert_eq(offers.get_child_count(), 4)
	var button: Button = offers.get_child(2).get_child(0) as Button
	assert_true(button.text.contains(HAG_PROFILE.catalog[2].display_name))
	assert_true(button.text.contains(str(HAG_PROFILE.catalog[2].market_price)))
	assert_true(button.tooltip_text.contains("инвентарь"))
	DayPhaseQueries.current().phase = C_DayCycle.Phase.MORNING
	button.pressed.emit()
	assert_eq(_money.balance, 1000)
	assert_true(_money.operations.is_empty())
	assert_true(InventoryService.items(_seller).is_empty())
	panel.close_panel()
	await get_tree().process_frame
	var inventory: C_Inventory = _seller.get_component(C_Inventory) as C_Inventory
	inventory.maximum_stacks = 1
	assert_true(InventoryService.grant(_seller, BONES, 1))
	DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
	assert_eq(
		CommerceService.purchase(_seller, hag, HAG_PROFILE.catalog[2], 1, &"hag/full"),
		CommerceService.Status.INVENTORY_FULL,
	)
	assert_eq(_money.balance, 1000)
	assert_true(_money.operations.is_empty())
	assert_true(CommerceService.current().receipts.is_empty())
	InventoryService.clear_owner(_seller)
	_money.balance = 0
	assert_eq(
		CommerceService.purchase(_seller, hag, HAG_PROFILE.catalog[0], 1, &"hag/poor"),
		CommerceService.Status.INSUFFICIENT_FUNDS,
	)
	assert_true(_money.operations.is_empty())
	assert_true(InventoryService.items(_seller).is_empty())


func test_receipt_owned_goods_and_role_survive_disk_death_and_return_without_free_copy() -> void:
	var hag: E_DistrictNpc = _open_hag_shop()
	var definition: DEF_InventoryItem = HAG_PROFILE.catalog[2]
	assert_eq(
		CommerceService.purchase(_seller, hag, definition, 1, &"hag/save"),
		CommerceService.Status.COMMITTED,
	)
	var item_id: String = _owned(definition).id
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(_owned(definition).id, item_id)
	assert_eq(
		CommerceService.purchase(_seller, hag, definition, 1, &"hag/save"),
		CommerceService.Status.DUPLICATE,
	)
	assert_eq(InventoryService.items(_seller).size(), 1)
	assert_eq(_money.operations.size(), 1)
	_kill(NpcPopulationQueries.person_for(&"npc/6"))
	assert_eq(
		CommerceService.purchase(_seller, hag, definition, 1, &"hag/dead"),
		CommerceService.Status.INVALID,
	)
	_morning(3)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
	assert_same(NpcPopulationQueries.body_for(&"npc/6"), hag)
	assert_same((hag.get_component(C_Trader) as C_Trader).profile, HAG_PROFILE)
	assert_eq(
		CommerceService.purchase(_seller, hag, definition, 1, &"hag/save"),
		CommerceService.Status.DUPLICATE,
	)
	assert_eq(_money.operations.size(), 1)
	assert_eq((_owned(definition).get_component(C_InventoryItem) as C_InventoryItem).quantity, 1)
#endregion


#region Real player input and native modal handoff
func test_actual_head_ray_opens_public_shop_then_buyback_without_competing_focus() -> void:
	var hag: E_DistrictNpc = _open_hag_shop()
	var player: E_CharacterBodyPlayer = (
		load("res://content/domains/motion/entities/character_body_player.tscn") as PackedScene
	).instantiate() as E_CharacterBodyPlayer
	EntityCompositionFixture.register(_world, player)
	for child: Node in player.find_children("*", "Entity", true, false):
		EntityCompositionFixture.register(_world, child as Entity, false)
	player.set_physics_process(false)
	var point: Vector3 = (hag as Node as Node3D).global_position
	player.global_position = point + Vector3(0, 0, 2)
	var ray: RayCast3D = player.interaction_ray_cast
	ray.global_position = point + Vector3(0, 1.2, 2)
	ray.look_at(point + Vector3.UP * 1.2)
	await _physics_settled()
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(player, interactor)
	assert_same(interactor.target, hag)
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(
		player,
		DEF_InteractionAction.Slot.USE,
	)
	assert_not_null(choice)
	if choice == null:
		return
	assert_true(choice.action is DEF_TraderAction)
	assert_eq(choice.action.caption, "Торговля")
	assert_true(
		InteractionActionResolver.execute_slot(player, DEF_InteractionAction.Slot.USE, true)
	)
	_world.flush_command_buffers()
	var panel: CommercePanel = player.find_child("CommercePanel", false, false) as CommercePanel
	assert_not_null(panel)
	if panel == null:
		return
	var button: Button = panel.get_node("Root/Center/Panel/Content/BuybackButton") as Button
	assert_true(button.visible)
	button.pressed.emit()
	_world.flush_command_buffers()
	assert_true(panel.is_queued_for_deletion())
	var buyback: BuybackPanel = player.find_child("BuybackPanel", false, false) as BuybackPanel
	assert_not_null(buyback)
	if buyback != null:
		assert_eq(InteractionControlFocus.current(player), InteractionControlFocus.Priority.MODAL)
		buyback.close_panel()
	assert_lt(InteractionControlFocus.current(player), InteractionControlFocus.Priority.MODAL)
	assert_true(_money.operations.is_empty())
	await get_tree().process_frame
#endregion


#region Authored provider rejection
func test_scene_provider_requires_its_authored_trader_and_cannot_fall_back_to_role_map() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/6")
	var card: DEF_NpcPerson = _district.definition.person_for(person.npc_id)
	var body: E_DistrictNpc = (
		(load(card.npc_scene_path) as PackedScene).instantiate() as E_DistrictNpc
	)
	var roles: ET_NpcRoles = (
		load("res://content/domains/npc/authoring/et_district_npc_npc_roles.tres") as ET_NpcRoles
	).duplicate() as ET_NpcRoles
	roles.trader_provider = ET_NpcRoles.Provider.SCENE
	roles.trader_profile = null
	var traits: Array[EntityTrait] = body.traits.duplicate()
	for index: int in traits.size():
		if traits[index] is ET_NpcRoles:
			traits[index] = roles
	body.traits = traits
	var context: EntitySpawnContext = EntityCompositionService.context_for(
		body,
		_world,
		"hag/invalid-scene-provider",
	)
	NpcConstructionService.configure_context(context, person, _district.definition)
	var count: int = _world.entities.size()
	var plan: EntityBuildPlan = EntityCompositionService.registration_plan(context)
	assert_false(plan.valid(), "SCENE cannot consume a second Trait-owned public shop mapping")
	roles.role_profiles = { }
	roles.role_trade_action = null
	var merchant: DEF_NpcProfile = person.profile.duplicate() as DEF_NpcProfile
	merchant.merchant = true
	context.definitions[&"npc_profile"] = merchant
	plan = EntityCompositionService.registration_plan(context)
	assert_false(plan.valid(), "SCENE still requires an authored C_Trader; no Trait fallback")
	assert_eq(_world.entities.size(), count)
	assert_false(_world.entity_to_archetype.has(body))
	body.free()
#endregion
