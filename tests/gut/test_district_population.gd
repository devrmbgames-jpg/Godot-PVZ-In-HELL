extends GutTest
## Регрессии постоянства населения, календаря, окончательной смерти и отложенного заселения.

var _root: Node3D = null
var _world: World = null
var _district: C_District = null

#region Тестовое окружение
## Создаёт минимальный World с реальными районными профилями и prefab NPC.
func before_each() -> void:
	_root = Node3D.new()
	add_child(_root)
	var marker: Node3D = Node3D.new()
	marker.name = "District"
	_root.add_child(marker)
	_world = World.new()
	_root.add_child(_world)
	ECS.world = _world
	DialogueUiFixture.install()
	NpcCustomerComposition.install(_world)

	var owner_node: Node = Node.new()
	owner_node.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var owner_entity: Entity = owner_node as Entity
	_district = C_District.new()
	_district.definition = load("res://content/domains/npc/definitions/def_district_default.tres") as DEF_District
	owner_entity.component_resources = [_district, C_DayCycle.new()]
	_world.add_entity(owner_entity)
	_district = owner_entity.get_component(C_District) as C_District
	_world.add_observer(O_DistrictLifecycle.new())
	_world.add_observer(O_CustomerPlanning.new())
	DistrictPopulationService.initialize()

## Освобождает World до окружающей сцены и сбрасывает глобальное участие ECS.
func after_each() -> void:
	for actor: Entity in _world.entities.duplicate():
		if is_instance_valid(actor):
			_world.remove_entity(actor)
	_world.purge(false)
	ECS.world = null
	_root.free()
	_root = null
	_world = null
	_district = null
#endregion

#region Личность и расписание
## Постоянный торговец достигает своей точки и остаётся доступен во всех игровых фазах.
func test_merchant_schedule_keeps_same_live_trader_on_shop_goal_all_day() -> void:
	var person: NpcRecord = _district.people[7]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var shop: C_Trader = body.get_component(C_Trader) as C_Trader
	assert_true(person.profile.merchant)
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.DAY, C_DayCycle.Phase.EVENING]:
		cycle.phase = phase
		assert_true(DistrictPopulationService.request_phase(body, 1, phase).succeeded)
		assert_eq(person.profile.schedule.location_for(1, phase), DEF_NpcSchedule.Location.STREET)
		assert_eq(_district.definition.place_for(person.goal_id).kind, DEF_DistrictPlace.Kind.SHOP)
		assert_true(DistrictPopulationService.request_phase_completion(body).succeeded)
		assert_eq(person.placement, NpcRecord.Placement.STREET)
		assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
		assert_true(GrabService.holder_available(body))
		assert_true(TraderCatalogRules.is_open(shop, cycle))
	cycle.phase = C_DayCycle.Phase.NIGHT
	assert_false(TraderCatalogRules.is_open(shop, cycle))

## Уход и возвращение сохраняют постоянный ID, тот же экземпляр тела, здоровье и память.
func test_departure_and_return_keep_body_health_and_memory() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = health.value * 0.5
	var memory: NpcMemory = NpcMemory.new()
	memory.actor_id = &"player"
	memory.incident_id = &"test/help"
	person.memories.append(memory)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	assert_false(body.enabled)
	assert_eq((body as Node as RigidBody3D).collision_layer, 0)
	assert_true(DistrictPopulationService.request_phase(body, 2, C_DayCycle.Phase.MORNING).succeeded)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_true(body.enabled)
	assert_eq(health.current, health.value * 0.5)
	assert_eq(person.memories.size(), 1)

## Доступность приезжего задаётся игровым днём недели, а не длительностью фазы.
func test_weekly_visitor_uses_day_index() -> void:
	var visitor: NpcRecord = _district.people[8]
	assert_eq(visitor.profile.schedule.location_for(1, C_DayCycle.Phase.DAY), DEF_NpcSchedule.Location.STREET)
	assert_eq(visitor.profile.schedule.location_for(2, C_DayCycle.Phase.DAY), DEF_NpcSchedule.Location.OUTSIDE)
	assert_eq(visitor.profile.schedule.location_for(8, C_DayCycle.Phase.DAY), DEF_NpcSchedule.Location.STREET)

## Повтор подготовки того же утра не создаёт личность и не сбрасывает фазу повторно.
func test_morning_retry_is_idempotent() -> void:
	var count: int = _district.people.size()
	DistrictPopulationService.prepare_morning(2)
	var planned: int = _district.people[0].planned_day
	DistrictPopulationService.prepare_morning(2)
	assert_eq(_district.people.size(), count)
	assert_eq(_district.people[0].planned_day, planned)
	assert_eq(_district.prepared_morning, 2)
#endregion

#region Исполнение дерева решений
## Реальное дерево LimboAI исполняет расписание через арбитр намерений движения.
func test_native_tree_drives_schedule_without_another_movement_owner() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	NpcAiFixture.advance(_district, 0.2)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var intent: C_NpcIntent = body.get_component(C_NpcIntent) as C_NpcIntent
	assert_not_null(body.get_node_or_null("Brain") as BTPlayer)
	assert_eq(decision.intent_owner, C_NpcDecision.Owner.SCHEDULE)
	assert_true(intent.movement_active)
	assert_eq(intent.move_position, NpcPopulationQueries.position_for(person.goal_id))
#endregion

#region Окончательная смерть и заселение
## Заселение после двух смертей создаёт новый ID без чужой памяти; погибший остаётся в истории.
func test_two_deaths_start_delayed_one_per_morning_resettlement() -> void:
	var first: NpcRecord = _district.people[0]
	var second: NpcRecord = _district.people[1]
	var first_id: StringName = first.npc_id
	var first_home: StringName = first.home_id
	DistrictPopulationService.mark_dead(first, NpcPopulationQueries.body_for(first_id), 1)
	assert_eq(_district.replacement_morning, 0)
	DistrictPopulationService.mark_dead(second, NpcPopulationQueries.body_for(second.npc_id), 1)
	assert_eq(_district.replacement_morning, 3)
	DistrictPopulationService.prepare_morning(2)
	assert_eq(_district.people.size(), 12)
	DistrictPopulationService.prepare_morning(3)
	assert_eq(_district.people.size(), 13)

	var replacement: NpcRecord = _district.people.back()
	assert_ne(replacement.npc_id, first_id)
	assert_eq(replacement.home_id, first_home)
	assert_eq(replacement.memories.size(), 0)
	assert_eq(first.placement, NpcRecord.Placement.DEAD)
	DistrictPopulationService.prepare_morning(3)
	assert_eq(_district.people.size(), 13)
	DistrictPopulationService.prepare_morning(4)
	assert_eq(_district.people.size(), 14)
	assert_eq(_district.replacement_morning, 0)
#endregion
