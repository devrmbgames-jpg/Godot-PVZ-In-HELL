extends GutTest
## Проверяет срок жизни клиента и интервалы очереди без навигации и отрисовки.

var _world: World
var _flow: C_CustomerFlow
var _cycle: C_DayCycle


#region Тестовое окружение
## Создаёт минимальный World со стойкой и дневной очередью; поставка и prefab отключены.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new()]
	_world.add_entity(session)
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_flow.schedule = DEF_CustomerSchedule.new()
	_flow.schedule.supply = null
	_flow.schedule.customer_scene = load("res://content/domains/customers/entities/customer.tscn") as PackedScene

	var counter_scene: PackedScene = load("res://content/domains/customers/entities/delivery_counter.tscn") as PackedScene
	var counter: E_DeliveryCounter = counter_scene.instantiate() as E_DeliveryCounter
	_world.add_entity(counter)


## Удаляет World и очищает глобальную ссылку ECS.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _advance_challenge(delta: float) -> void:
	var owner: S_ChallengeRuntime = S_ChallengeRuntime.new()
	owner.group = "challenge_fixture"
	_world.add_system(owner)
	_world.process(delta, owner.group)
	_world.remove_system(owner)
	owner.free()


func _visit(id: StringName) -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = id
	visit.definition = DEF_Customer.new()
	visit.definition.max_followup_visits = 0
	visit.requires_registered_package = false
	_flow.visits.append(visit)
	return visit


func _leaving_customer(visit: CustomerVisit) -> E_NpcCharacter:
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/domains/customers/entities/e_customer.gd"))
	var customer: E_NpcCharacter = body as Node as E_NpcCharacter
	customer.component_resources = [C_CustomerAgent.new(), C_NpcIntent.new()]
	_world.add_entity(customer)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	agent.phase = C_CustomerAgent.Phase.LEAVING
	visit.started = true
	visit.visit_count = 1
	return customer


#endregion

#region Explicit lifecycle owners
## A phase entered by arrival does not execute again later in the same scheduled step.
func test_arrival_and_greeting_consume_distinct_phase_steps() -> void:
	var visit: CustomerVisit = _visit(&"phase-snapshot")
	visit.definition.greeting_seconds = 0.0
	visit.definition.patience_seconds = 0.0
	var customer: E_NpcCharacter = _leaving_customer(visit)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.APPROACHING
	(customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true

	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING)
	assert_eq(agent.elapsed, 0.0)
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_eq(agent.phase, C_CustomerAgent.Phase.LEAVING)
	assert_false(visit.finished, "Entering departure does not also remove the appearance")


## Phase consumers share one clock increment rather than accumulating delta independently.
func test_isolated_phase_clock_advances_once_per_world_step() -> void:
	var visit: CustomerVisit = _visit(&"one-clock")
	visit.definition.patience_seconds = 10.0
	var customer: E_NpcCharacter = _leaving_customer(visit)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE

	CustomerFlowFixture.advance(_flow, _cycle, 0.25)
	assert_almost_eq(agent.elapsed, 0.25, 0.0001)
	CustomerFlowFixture.advance(_flow, _cycle, 0.25)
	assert_almost_eq(agent.elapsed, 0.5, 0.0001)
	assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)


## Retained roles consume due-step facts synchronously, independent of structural flush mode.
func test_district_role_clock_does_not_advance_on_isolated_frame_or_structural_flush() -> void:
	var visit: CustomerVisit = _visit(&"district-clock")
	var customer: E_NpcCharacter = _leaving_customer(visit)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	customer.add_component(C_NpcIdentity.new())
	CustomerFlowFixture.advance(_flow, _cycle, 0.1)
	assert_eq(agent.elapsed, 0.0)

	for observer: Observer in _world.observers:
		if observer is O_CustomerServiceClock:
			observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	CustomerFlowFixture.decision_ready(customer, 0.2)
	assert_almost_eq(agent.elapsed, 0.2, 0.0001)
	_world.flush_command_buffers()
	assert_almost_eq(agent.elapsed, 0.2, 0.0001)
	CustomerFlowFixture.decision_ready(customer, 0.4)
	assert_almost_eq(agent.elapsed, 0.6, 0.0001)
#endregion

#region Уход и интервалы очереди
## Старый короткий таймаут выхода ограничивается минимумом в три минуты.
func test_legacy_short_departure_cannot_remove_customer_before_three_minutes() -> void:
	var visit: CustomerVisit = _visit(&"blocked-exit")
	visit.definition.leaving_seconds = 2.0
	var customer: E_NpcCharacter = _leaving_customer(visit)
	CustomerFlowFixture.advance(_flow, _cycle, 180.0)
	assert_eq(CustomerFlowQueries.customer_for(visit.visit_id), customer)
	assert_false(visit.finished)
	assert_eq(_flow.arrival_cooldown_seconds, 0.0)
	CustomerFlowFixture.advance(_flow, _cycle, 1.0)
	assert_null(CustomerFlowQueries.customer_for(visit.visit_id))
	assert_true(visit.finished)
	assert_eq(_flow.arrival_cooldown_seconds, 30.0)


## Прибытие к выходу немедленно освобождает клиента; повторное завершение не перезапускает паузу.
func test_arriving_at_exit_finishes_immediately_and_starts_gap_once() -> void:
	var visit: CustomerVisit = _visit(&"exit-arrived")
	var customer: E_NpcCharacter = _leaving_customer(visit)
	(customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowFixture.advance(_flow, _cycle, 0.1)
	assert_null(CustomerFlowQueries.customer_for(visit.visit_id))
	assert_true(visit.finished)
	_flow.arrival_cooldown_seconds = 7.0
	CustomerVisitLifecycle.finish(visit, _cycle.day_index)
	assert_eq(_flow.arrival_cooldown_seconds, 7.0, "Duplicate completion cannot restart the gap")


## Следующий клиент ждёт физического ухода предыдущего и авторской паузы в секундах.
func test_next_eligible_customer_waits_for_configured_gap_after_previous_departure() -> void:
	_flow.schedule.arrival_interval_seconds = 45.0
	var previous: CustomerVisit = _visit(&"previous")
	var customer: E_NpcCharacter = _leaving_customer(previous)
	var next: CustomerVisit = _visit(&"next")
	assert_false(CustomerFlowFixture.spawn(_flow, _cycle), "Leaving NPC still occupies the visit slot")
	(customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowFixture.advance(_flow, _cycle, 0.1)
	assert_false(next.started)
	CustomerFlowFixture.advance(_flow, _cycle, 44.0)
	assert_false(next.started)
	assert_string_contains(CustomerDebugPresentation.summary(), "Пауза до следующего: 1 с")
	CustomerFlowFixture.advance(_flow, _cycle, 1.0)
	assert_true(next.started)
	assert_not_null(CustomerFlowQueries.customer_for(next.visit_id))
	assert_eq(next.visit_count, 1)


## Первый визит доступен сразу; утро очищает паузу предыдущего дня.
func test_first_customer_and_morning_are_not_delayed_by_previous_day_gap() -> void:
	var first: CustomerVisit = _visit(&"first")
	assert_true(CustomerFlowFixture.spawn(_flow, _cycle))
	assert_not_null(CustomerFlowQueries.customer_for(first.visit_id))
	_flow.arrival_cooldown_seconds = 30.0
	_cycle.phase = C_DayCycle.Phase.MORNING
	CustomerFlowFixture.advance(_flow, _cycle, 0.0)
	assert_eq(_flow.arrival_cooldown_seconds, 0.0)


## Живой обслуживаемый клиент блокирует обычный и отладочный приход даже после завершения учёта.
func test_single_live_customer_blocks_queue_and_debug_even_after_accounting_finished() -> void:
	var previous: CustomerVisit = _visit(&"still-physically-present")
	var customer: E_NpcCharacter = _leaving_customer(previous)
	var queued: CustomerVisit = _visit(&"queued")
	previous.finished = true
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	for phase: C_CustomerAgent.Phase in [C_CustomerAgent.Phase.RECEIVING, C_CustomerAgent.Phase.GOING_TO_BOOTH, C_CustomerAgent.Phase.INSPECTING, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH, C_CustomerAgent.Phase.AGGRESSIVE, C_CustomerAgent.Phase.LEAVING]:
		agent.phase = phase
		assert_false(CustomerFlowFixture.spawn(_flow, _cycle))
		assert_false(DebugWorldService.customer_next().success)
		assert_false(queued.started)
		assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 1)
	_world.remove_entity(customer)
	assert_true(CustomerFlowFixture.spawn(_flow, _cycle))
	assert_true(queued.started)
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 1)


## Завершение не начатого визита не создаёт паузу для первой встречи.
func test_unspawned_visit_completion_does_not_add_artificial_delay() -> void:
	var missed: CustomerVisit = _visit(&"unspawned")
	CustomerVisitLifecycle.finish(missed, _cycle.day_index)
	assert_true(missed.finished)
	assert_eq(_flow.arrival_cooldown_seconds, 0.0)
	var next: CustomerVisit = _visit(&"first-real")
	assert_true(CustomerFlowFixture.spawn(_flow, _cycle))
	assert_true(next.started)
	assert_eq(missed.visit_count, 0, "Already finished unspawned visits cannot spawn again")


#endregion

#region Авторские таймауты
## Проверяет авторские таймауты старых испытаний взгляда и выключения света.
func test_authored_gaze_has_twelve_seconds_and_light_entrance_is_not_scaled_twice() -> void:
	var gaze: DEF_Challenge = load("res://content/domains/challenges/definitions/def_challenge_dont_look.tres") as DEF_Challenge
	var state: C_Challenge = C_Challenge.new()
	state.definition = gaze
	var subject: Entity = Entity.new()
	subject.component_resources = [state]
	_world.add_entity(subject)
	state = subject.get_component(C_Challenge) as C_Challenge

	var actor: Entity = Entity.new()
	_world.add_entity(actor)
	assert_true(ChallengeService.arm(subject, actor))
	assert_true(ChallengeService.activate(subject))
	state.condition_result = ChallengeResult.Type.FAILURE
	_advance_challenge(11.9)
	assert_null(state.pending_result)
	_advance_challenge(0.1)
	assert_not_null(state.pending_result)
	assert_eq(state.pending_result.result, ChallengeResult.Type.FAILURE)

	var entrance: DEF_Challenge = load("res://content/domains/challenges/definitions/def_challenge_light_entrance.tres") as DEF_Challenge
	assert_eq(entrance.timeout_seconds, 80.0)


#endregion

#region Приход в одном CommandBuffer
## Два запроса в одном CommandBuffer создают одного клиента до обновления кеша запросов.
func test_two_arrival_requests_in_one_command_batch_spawn_only_one_customer() -> void:
	var first: CustomerVisit = _visit(&"batch-first")
	var second: CustomerVisit = _visit(&"batch-second")
	var commands: CommandBuffer = CommandBuffer.new(_world)
	commands.add_custom(func() -> void: CustomerFlowFixture.spawn(_flow, _cycle))
	commands.add_custom(func() -> void: CustomerFlowFixture.spawn(_flow, _cycle))
	commands.execute()
	assert_true(first.started)
	assert_false(second.started, "A newly created customer blocks the next request before query-cache invalidation")
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 1)


## Повторный tick в том же пакете видит созданного клиента и сохраняет следующий визит в очереди.
func test_repeated_flow_ticks_in_one_batch_keep_first_visit_and_next_queued() -> void:
	var first: CustomerVisit = _visit(&"tick-first")
	var second: CustomerVisit = _visit(&"tick-second")
	var commands: CommandBuffer = CommandBuffer.new(_world)
	commands.add_custom(CustomerFlowFixture.advance.bind(_flow, _cycle, 0.0))
	commands.add_custom(func() -> void:
		assert_not_null(CustomerFlowQueries.customer_for(first.visit_id), "Registered customer is visible before cache invalidation")
	)
	commands.add_custom(CustomerFlowFixture.advance.bind(_flow, _cycle, 0.0))
	commands.execute()
	assert_true(first.started)
	assert_false(first.finished, "Cache delay must not finish a physically present visit")
	assert_false(second.started)
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 1)

#endregion

#region Prepared customer visit construction
## Factory publication exposes complete role/Profile defaults before consumers run.
func test_customer_factory_publishes_visit_policy_before_entity_added() -> void:
	var visit: CustomerVisit = _visit(&"prepared-customer")
	visit.definition.move_speed = 4.75
	var published: Array[Entity] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		var agent: C_CustomerAgent = actor.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent == null:
			return
		assert_eq(agent.visit_id, visit.visit_id)
		assert_true(visit.started)
		assert_eq(visit.visit_count, 1)
		assert_eq((actor.get_component(C_Motion) as C_Motion).max_speed, 4.75)
		assert_same((actor.get_component(C_Challenge) as C_Challenge).definition,
			visit.definition.challenge)
		var actions: C_InteractionActionSet = actor.get_component(C_InteractionActionSet) \
			as C_InteractionActionSet
		assert_eq(actions.actions.size(), 2)
		assert_true(actions.actions[0] is DEF_CustomerAction)
		assert_true(actions.actions[1] is DEF_CustomerHandoffAction)
		published.append(actor))
	CustomerFlowService.start_visit(_flow, visit, 1)
	assert_eq(published.size(), 1)
	assert_true(visit.started)
	assert_eq(visit.visit_count, 1)


## Conflicting providers leave visit/history/registry/SceneTree unchanged.
func test_rejected_customer_recipe_preserves_unstarted_visit() -> void:
	var visit: CustomerVisit = _visit(&"rejected-customer")
	var template: DEF_EntityTemplate = load(
		"res://content/domains/customers/definitions/def_entity_customer_visit.tres") \
		as DEF_EntityTemplate
	var duplicate: EntityTrait = EntityTrait.new()
	duplicate.trait_id = &"conflicting-motion"
	duplicate.component_recipes = [C_Motion.new()]
	template.traits.append(duplicate)
	var entity_count: int = _world.entities.size()
	var child_count: int = get_child_count()
	CustomerFlowService.start_visit(_flow, visit, 1)
	template.traits.erase(duplicate)
	assert_false(visit.started)
	assert_false(visit.finished)
	assert_eq(visit.visit_count, 0)
	assert_eq(visit.last_visit_day, 0)
	assert_eq(_world.entities.size(), entity_count)
	assert_eq(get_child_count(), child_count)


## An inherited content variant uses the same Template without another Trait or registry edit.
func test_customer_scene_variant_uses_same_role_template() -> void:
	var visit: CustomerVisit = _visit(&"variant-customer")
	visit.definition.customer_scene_path = \
		"res://content/domains/customers/entities/customer_prototype.tscn"
	CustomerFlowService.start_visit(_flow, visit, 1)
	var actor: Entity = _world.query.with_all([C_CustomerAgent]).execute_one()
	assert_not_null(actor)
	assert_eq(actor.scene_file_path, visit.definition.customer_scene_path)
	assert_eq((actor.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id, visit.visit_id)
	assert_true(actor.has_component(C_InteractionActionSet))
	assert_eq((actor as E_Customer).inspection_animation, &"Idle")
#endregion

#region Rejected customer inputs
## Wrong scene roots and missing prefab selectors cannot finish or charge an unstarted visit.
func test_invalid_customer_scene_preserves_visit_and_native_registry() -> void:
	for scene_path: String in [
		"res://content/domains/npc/entities/npc_address.tscn", "res://" + "missing_customer.tscn",
	]:
		var visit: CustomerVisit = _visit(StringName(scene_path))
		visit.definition.customer_scene_path = scene_path
		var count_before: int = _world.entities.size()
		CustomerFlowService.start_visit(_flow, visit, 1)
		assert_false(visit.started)
		assert_false(visit.finished)
		assert_eq(visit.visit_count, 0)
		assert_eq(_world.entities.size(), count_before)
#endregion

#region Scene-owned customer recipe parity
## Placed preview and factory compilation share isolated role state and immutable Definitions.
func test_customer_scene_compiles_without_factory_and_isolates_mutable_role_state() -> void:
	var first: Entity = _flow.schedule.customer_scene.instantiate() as Entity
	var second: Entity = _flow.schedule.customer_scene.instantiate() as Entity
	var first_context: EntitySpawnContext = EntityCompositionService.context_for(
		first, null, "first")
	var second_context: EntitySpawnContext = EntityCompositionService.context_for(
		second, null, "second")
	var first_plan: EntityBuildPlan = EntityCompositionService.build_plan(first_context)
	var second_plan: EntityBuildPlan = EntityCompositionService.build_plan(second_context)
	assert_true(first_plan.valid())
	assert_true(second_plan.valid())
	var first_agent: C_CustomerAgent = null
	var second_agent: C_CustomerAgent = null
	var first_actions: C_InteractionActionSet = null
	var second_actions: C_InteractionActionSet = null
	for recipe: Component in first_plan.component_recipes:
		if recipe is C_CustomerAgent:
			first_agent = recipe as C_CustomerAgent
		if recipe is C_InteractionActionSet:
			first_actions = recipe as C_InteractionActionSet
	for recipe: Component in second_plan.component_recipes:
		if recipe is C_CustomerAgent:
			second_agent = recipe as C_CustomerAgent
		if recipe is C_InteractionActionSet:
			second_actions = recipe as C_InteractionActionSet
	assert_not_same(first_agent, second_agent)
	assert_same(first_actions.actions[0], second_actions.actions[0])
	first_agent.visit_id = &"only-first"
	first_actions.actions.remove_at(0)
	assert_eq(second_agent.visit_id, &"")
	assert_eq(second_actions.actions.size(), 2)
	assert_false(EntityCompositionService.recipes_prepared(first))
	first.free()
	second.free()
#endregion
