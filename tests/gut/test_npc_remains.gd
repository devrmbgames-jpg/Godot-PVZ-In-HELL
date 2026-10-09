extends GutTest
## Реальный урон, физическое тело NPC, съедобные предметы и сохранение окончательной смерти.

var _root: Node3D
var _world: World
var _actor: Entity


#region Физические предметы и сессия
## Создаёт реальный pipeline урона/инвентаря, физический пол, вечернюю сессию и голодного игрока.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HealthLifecycle.new())
	_world.add_observer(O_NpcRemains.new())
	_world.add_observer(O_InventoryEffect.new())
	_world.add_observer(O_InventoryLifecycle.new())

	var session: Entity = Entity.new()
	session.component_resources = [
		C_DayCycle.new(),
		C_LootDrops.new(),
		C_Wallet.new(),
		C_Commerce.new(),
		C_CustomerFlow.new(),
	]
	_root.add_child(session)
	session.owner = _root
	FixturePlacedIdentity.assign(_root, session, &"session")
	_world.add_entity(session, null, false)
	(session.get_component(C_DayCycle) as C_DayCycle).phase = C_DayCycle.Phase.EVENING
	(session.get_component(C_Wallet) as C_Wallet).balance = 500
	_actor = Entity.new()

	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = load("res://content/domains/needs/definitions/def_hunger_default.tres") as DEF_HungerPolicy
	hunger.value = 80.0
	_actor.component_resources = [C_Inventory.new(), C_GrabControl.new(), C_Controller.new(), C_Health.new(), hunger, C_PlayerInputController.new()]
	_root.add_child(_actor)
	_actor.owner = _root
	FixturePlacedIdentity.assign(_root, _actor, &"actor")
	_world.add_entity(_actor, null, false)
	var floor: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30, 0.2, 30)
	collision.shape = shape
	collision.position.y = -0.1
	floor.add_child(collision)
	_root.add_child(floor)
	await get_tree().physics_frame
	await get_tree().physics_frame


## Очищает World до удаления сценового корня и сбрасывает глобальный ECS.world.
func after_each() -> void:
	_world.purge(false)
	_root.free()
	ECS.world = null


func _npc(customer: bool = false, loot_chance: float = 0.0) -> E_NpcCharacter:
	var path: String = "res://content/domains/customers/entities/customer.tscn" if customer else "res://content/domains/commerce/entities/trader.tscn"
	var npc: E_NpcCharacter = (load(path) as PackedScene).instantiate() as E_NpcCharacter
	var components: Array[Component] = npc.component_resources.duplicate()
	for index: int in components.size():
		if not components[index] is C_NpcRemains:
			continue

		var remains: C_NpcRemains = C_NpcRemains.new()
		remains.definition = (load("res://content/domains/npc/definitions/def_npc_remains_default.tres") as DEF_NpcRemains).duplicate() as DEF_NpcRemains
		remains.definition.loot_chance = loot_chance
		components[index] = remains
	npc.component_resources = components
	(npc as Node as RigidBody3D).freeze = true
	_root.add_child(npc)
	EntityCompositionFixture.register(_world, npc, false)
	return npc


func _damage(npc: Entity, amount: float) -> void:
	var request: DamageRequest = DamageRequest.new()
	request.target = npc
	request.source = _actor
	request.instigator = _actor
	request.damage_type = DamageRequest.Type.MELEE
	request.amount = amount
	DamageRequestService.submit(request)


func _drops() -> Array[Entity]:
	return _world.query.with_all([C_InventoryItem]).execute().duplicate()


#endregion

#region Дроп и употребление
## Ранение не создаёт дроп; смерть даёт три отдельные единицы мяса и гарантированную QA-аптечку ровно один раз.
func test_actual_death_creates_three_edible_pieces_and_guaranteed_medkit_once() -> void:
	var npc: E_NpcCharacter = _npc(false, 1.0)
	_damage(npc, 10.0)
	assert_true(_drops().is_empty(), "A living wounded NPC produces no remains")
	_damage(npc, 200.0)
	assert_true(npc.has_component(C_Death))
	assert_true((npc.get_component(C_NpcRemains) as C_NpcRemains).released)
	assert_eq(_drops().size(), 4)

	var meat_count: int = 0
	var med_count: int = 0
	for drop: Entity in _drops():
		var item: C_InventoryItem = drop.get_component(C_InventoryItem) as C_InventoryItem
		assert_eq(item.quantity, 1)
		assert_null(InventoryService.owner_for(drop))
		assert_false(item.definition.resource_path.is_empty())
		if item.definition.key == &"npc_meat":
			meat_count += 1
			assert_true((drop.get_node("Visual/Meat") as MeshInstance3D).mesh is CylinderMesh)
			assert_true((drop.get_node("Visual/Bone") as MeshInstance3D).mesh is CylinderMesh)
			assert_almost_eq((drop as Node as Node3D).global_position.y, 0.15, 0.01)
		else:
			med_count += 1
			assert_eq(item.definition.key, &"med")
	assert_eq(meat_count, 3)
	assert_eq(med_count, 1)
	_damage(npc, 200.0)
	assert_eq(_drops().size(), 4, "Repeated lethal requests cannot duplicate a batch")


## Реальное мясо собирается в стопку и расходуется по единице, уменьшая голод без остаточных предметов.
func test_meat_is_pickable_consumable_food_and_reduces_actual_hunger() -> void:
	_damage(_npc(), 200.0)
	for drop: Entity in _drops():
		assert_true(InventoryService.transfer(drop, _actor))
	var items: Array[Entity] = InventoryService.items(_actor)
	assert_eq(items.size(), 1)
	var meat: Entity = items[0]
	assert_eq((meat.get_component(C_InventoryItem) as C_InventoryItem).quantity, 3)
	assert_true(InventoryService.use(_actor, meat))
	assert_eq((_actor.get_component(C_Hunger) as C_Hunger).value, 55.0)
	assert_eq((meat.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_true(InventoryService.use(_actor, meat))
	assert_true(InventoryService.use(_actor, meat))
	assert_eq((_actor.get_component(C_Hunger) as C_Hunger).value, 5.0)
	assert_true(InventoryService.items(_actor).is_empty())
	assert_true(_drops().is_empty())


#endregion

#region Смерть и восстановление
## Погибший торговец отключает тело/avoidance; покупка и открытие магазина отклоняются без списания денег.
func test_dead_trader_stops_native_body_avoidance_and_cannot_sell() -> void:
	var npc: E_NpcCharacter = _npc()
	_damage(npc, 200.0)
	var body: RigidBody3D = npc as Node as RigidBody3D
	assert_false(body.visible)
	assert_eq(body.collision_layer, 0)
	assert_eq(body.collision_mask, 0)
	assert_true(body.freeze)
	assert_false(npc.navigation_agent.avoidance_enabled)
	assert_false((npc.get_component(C_Motion) as C_Motion).control_enabled)

	var food: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_food.tres") as DEF_InventoryItem
	assert_eq(CommerceService.purchase(_actor, npc, food, 1, &"dead-trader"), CommerceService.Status.INVALID)
	assert_null(CommercePanelFactory.open(_actor, npc))
	assert_eq(WalletService.current().balance, 500)


## Snapshot и NightReset сохраняют смерть/released и уже созданную добычу без воскрешения или нового дропа.
func test_remains_and_dead_trader_restore_without_new_loot_or_night_resurrection() -> void:
	var npc: E_NpcCharacter = _npc(false, 1.0)
	_damage(npc, 200.0)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	var restored: E_NpcCharacter = _world.query.with_all([C_Trader]).execute_one() as E_NpcCharacter
	assert_true(restored.has_component(C_Death))
	assert_true((restored.get_component(C_NpcRemains) as C_NpcRemains).released)
	restored.sync_death_presentation()
	assert_false((restored as Node as Node3D).visible)
	assert_eq((restored as Node as RigidBody3D).collision_layer, 0)
	assert_eq(_drops().size(), 4)
	NightResetService.reset()
	assert_true(restored.has_component(C_Death))
	assert_eq(_drops().size(), 4)
	_damage(restored, 200.0)
	assert_eq(_drops().size(), 4)


## Смерть участника закрывает открытую торговую панель и возвращает игровой фокус.
func test_open_trading_panel_closes_and_releases_input_when_trader_dies() -> void:
	var npc: E_NpcCharacter = _npc()
	var panel: CommercePanel = CommercePanelFactory.open(_actor, npc)
	assert_not_null(panel)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	_damage(npc, 200.0)
	panel._process(0.0)
	assert_true(panel.is_queued_for_deletion())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	await get_tree().process_frame


## Завершение погибшего визита сохраняет физическое мясо и факты смерти/победы игрока.
func test_customer_remains_survive_visit_and_challenge_cleanup() -> void:
	var npc: E_NpcCharacter = _npc(true)
	var session: Entity = _world.query.with_all([C_CustomerFlow]).execute_one()
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	cycle.phase = C_DayCycle.Phase.DAY
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"dead-visitor"
	visit.definition = DEF_Customer.new()
	visit.definition.max_followup_visits = 0
	visit.started = true
	visit.visit_count = 1
	flow.visits.append(visit)
	(npc.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id = visit.visit_id
	_damage(npc, 200.0)
	assert_eq(_drops().size(), 3)
	CustomerFlowFixture.advance(flow, cycle, 0.1)
	assert_null(CustomerFlowQueries.customer_for(visit.visit_id))
	assert_true(visit.customer_dead)
	assert_true(visit.defeated_by_player)
	assert_true(visit.finished)
	assert_eq(_drops().size(), 3)
	for drop: Entity in _drops():
		assert_true(InventoryService.transfer(drop, _actor), "Visitor cleanup cannot own/remove its remains")


## Восстановленная отметка смерти отключает тело без повторного события урона и выдачи добычи.
func test_restored_terminal_marker_without_damage_does_not_spawn_loot() -> void:
	var npc: E_NpcCharacter = _npc(false, 1.0)
	(npc.get_component(C_Health) as C_Health).depleted = true
	npc.add_component(C_Death.new())
	npc.sync_death_presentation()
	assert_true(_drops().is_empty(), "Death restoration is not a new lethal hit")
	assert_false((npc as Node as Node3D).visible)

#endregion
