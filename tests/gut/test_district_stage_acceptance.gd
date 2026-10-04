extends "res://tests/gut/test_district_service_queue.gd"
## Приёмка настоящей цепи света, конечного мерцания и однократных социальных реакций района.

var _service_zone: NpcLightZone
var _light_view: CircuitLightView
var _light_switch: Entity
var _flicker_events: Array[LightFlickerEvent] = []

#region Окружение световой цепи
## Освобождает ссылки и запросы после штатного teardown унаследованного World.
func after_each() -> void:
	super.after_each()
	_service_zone = null
	_light_view = null
	_light_switch = null
	_flicker_events.clear()

func _install_service_light() -> void:
	var relay: O_LightFlicker = O_LightFlicker.new()
	_world.add_observer(relay)
	relay.flickering_light.connect(_remember_flicker)
	_light_switch = (load("res://content/entities/props/light_switch.tscn") as PackedScene).instantiate() as Entity
	_world.add_entity(_light_switch)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.name = "ServiceLamp"
	_root.add_child(lamp)
	lamp.add_to_group(&"warehouse_lights")
	_light_view = CircuitLightView.new()
	_light_view.name = "CircuitLightView"
	lamp.add_child(_light_view)
	_light_view.set_process(false)
	_service_zone = (load("res://content/scenes/npc_light_zone.tscn") as PackedScene).instantiate() as NpcLightZone
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20, 6, 20)
	(_service_zone.get_node("CollisionShape3D") as CollisionShape3D).shape = shape
	_service_zone.position = Vector3(0, 2, -1)
	_service_zone.circuit_id = &"warehouse"
	_service_zone.flicker_view_path = NodePath("../ServiceLamp/CircuitLightView")
	_root.add_child(_service_zone)

func _remember_flicker(event: LightFlickerEvent) -> void:
	_flicker_events.append(event)

func _light_averse_recipient(suffix: String) -> E_DistrictNpc:
	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(6, CustomerFlowService.counter().entry_position())
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	_district.people[6].profile.rules = [rule]
	_install_service_light()
	_case(_district.people[6], suffix)
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	assert_true(NpcServiceRole.enqueue_next(flow, DayPhaseService.current()))
	assert_true(_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2))
	assert_true(_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2))
	return body
#endregion

#region Свет, предупреждение и прерывание
## Повторные такты не перезапускают предупреждение и конечные часы настоящей лампы.
func test_light_warning_flickers_once_and_expires_without_allowing_entry() -> void:
	var body: E_DistrictNpc = _light_averse_recipient("finite_light")
	var service: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(_flicker_events.size(), 1)
	assert_eq(_flicker_events[0].kind, LightFlickerEvent.Kind.START)
	assert_true((body.get_node("Message") as Label3D).text.contains("Выключите"))
	_light_view._process(LightFlickerEvent.DEFAULT_INTERVAL_SECONDS * 1.1)
	assert_false(_service_zone.is_lit())
	assert_true(_service_zone.is_logically_lit())
	assert_true(NpcServiceRole.needs_darkness(body))
	assert_true(_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2))
	assert_eq(_flicker_events.size(), 1)
	assert_eq(service.phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	_light_view._process(_district.definition.service_flicker_seconds)
	for step: int in 3:
		assert_true(_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2))
	assert_true(_service_zone.is_lit())
	assert_true(LightCircuitService.is_enabled(&"warehouse"))
	assert_eq(_flicker_events.size(), 1)
	assert_eq(service.phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	assert_false(NpcServiceRole.visit_for(body).settlement_committed)

## Переключатель через настоящие сенсоры и корневой BT вызывает укрытие, без ручного флага тревоги.
func test_switch_and_sensors_drive_retreat_from_lit_counter() -> void:
	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(0)
	_player()
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	_district.people[0].profile.rules = [rule]
	_install_service_light()
	assert_true(LightCircuitService.set_enabled(_light_switch, false))
	var visit: CustomerVisit = _service(body, "actual_switch")
	NpcServiceRole.claim_counter(body)
	NpcBrainService.tick(_district, 0.3)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_false(awareness.light_distress)
	assert_true(body.has_component(C_CustomerAgent))
	assert_true(LightCircuitService.toggle(_light_switch))
	NpcBrainService.tick(_district, 0.3)
	assert_true(awareness.light_distress)
	assert_eq((body.get_component(C_NpcDecision) as C_NpcDecision).intent_owner, C_NpcDecision.Owner.EMERGENCY)
	assert_eq((body.get_component(C_NpcIntent) as C_NpcIntent).move_position, NpcTraitService.dark_refuge(body, _district.people[0]))
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(body.get_relationships(Relationship.new(R_NpcServiceAt.new(), CustomerFlowService.counter())).size(), 0)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_false(visit.settlement_committed)

## Уход с карты отменяет только запрос прихода и сохраняет включённый выключатель.
func test_departure_cancels_the_service_flicker() -> void:
	var body: E_DistrictNpc = _light_averse_recipient("departing_light")
	var request_id: StringName = _flicker_events[0].request_id
	_light_view._process(LightFlickerEvent.DEFAULT_INTERVAL_SECONDS * 1.1)
	assert_false(_service_zone.is_lit())
	DistrictPopulationService.set_placement(_district.people[6], body, NpcRecord.Placement.OUTSIDE)
	var cancellation: LightFlickerEvent = _flicker_events.back()
	assert_eq(cancellation.kind, LightFlickerEvent.Kind.STOP)
	assert_eq(cancellation.request_id, request_id)
	assert_true(_service_zone.is_lit())
	assert_true(LightCircuitService.is_enabled(&"warehouse"))
	assert_false(body.has_component(C_CustomerAgent))

## Смерть ожидающего NPC прекращает мерцание и не подменяет смерть выдачей.
func test_death_cancels_the_service_flicker_without_payment() -> void:
	var body: E_DistrictNpc = _light_averse_recipient("dead_light")
	var visit: CustomerVisit = NpcServiceRole.visit_for(body)
	_light_view._process(LightFlickerEvent.DEFAULT_INTERVAL_SECONDS * 1.1)
	body.add_component(C_Death.new())
	DistrictPopulationService.mark_dead(_district.people[6], body, DayPhaseService.current().day_index)
	var cancellation: LightFlickerEvent = _flicker_events.back()
	assert_eq(cancellation.kind, LightFlickerEvent.Kind.STOP)
	assert_true(_service_zone.is_lit())
	assert_true(LightCircuitService.is_enabled(&"warehouse"))
	assert_true(visit.customer_dead)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(visit.settlement_committed)

## Включение света после контрмеры не повторяет предупреждение и реакцию той же особенности в фазе.
func test_trait_warning_and_reaction_are_once_after_switching_light() -> void:
	var body: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	var person: NpcRecord = _district.people[0]
	person.profile.high_attack_probability = 1.0
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	rule.warning_seconds = 0.4
	rule.reaction_seconds = 0.4
	person.profile.rules = [rule]
	_install_service_light()
	await get_tree().physics_frame
	await get_tree().physics_frame
	NpcPerceptionService.sense(body, person, player, 0.2)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	assert_true(awareness.player_visible)
	NpcTraitService.tick(body, person, player, rule.warning_seconds)
	assert_eq(awareness.warned_rules.count(rule.kind), 1)
	assert_true(person.memories.is_empty())
	NpcTraitService.tick(body, person, player, rule.reaction_seconds)
	assert_eq(person.memories.size(), 1)
	assert_eq(awareness.reacted_rules.count(rule.kind), 1)
	assert_true(LightCircuitService.set_enabled(_light_switch, false))
	NpcTraitService.tick(body, person, player, 2.0)
	assert_eq(awareness.rule_exposure[rule.kind], 0.0)
	assert_true(LightCircuitService.set_enabled(_light_switch, true))
	NpcTraitService.tick(body, person, player, 2.0)
	assert_eq(awareness.warned_rules.count(rule.kind), 1)
	assert_eq(awareness.reacted_rules.count(rule.kind), 1)
	assert_eq(person.memories.size(), 1)
#endregion

#region Характер, риск и инциденты
## Реальный недостаток здоровья разрешает агрессивному NPC отступить даже при голоде игрока 30%.
func test_aggressive_retreat_requires_real_health_risk() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.personality = DEF_NpcProfile.Personality.AGGRESSIVE
	person.profile.high_attack_probability = 0.0
	person.profile.low_flee_probability = 1.0
	var player: E_DistrictNpc = _player()
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = DEF_HungerPolicy.new()
	hunger.value = 30.0
	player.add_component(hunger)
	(body.get_component(C_NpcAwareness) as C_NpcAwareness).player_visible = true
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"healthy_threat"), NpcMemory.Reaction.TALK)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = health.value * person.profile.pursuit_health_reserve * 0.5
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"wounded_threat"), NpcMemory.Reaction.FLEE)
	assert_true((body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing)
	assert_null(CombatService.target_for(body))

## Тот же инцидент сохраняет решение после смены риска и не применяет нападение повторно.
func test_repeated_incident_keeps_reaction_without_restarting_combat() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile.personality = DEF_NpcProfile.Personality.AGGRESSIVE
	person.profile.high_attack_probability = 1.0
	var player: E_DistrictNpc = _player()
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"same_threat"), NpcMemory.Reaction.ATTACK)
	assert_same(CombatService.target_for(body), player)
	CombatService.end_combat(body)
	person.profile.high_attack_probability = 0.0
	person.profile.low_flee_probability = 1.0
	(body.get_component(C_Health) as C_Health).current = 1.0
	for repeat_index: int in 4:
		assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"same_threat"), NpcMemory.Reaction.ATTACK)
	assert_eq(person.memories.size(), 1)
	assert_null(CombatService.target_for(body))
	assert_false((body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing)
#endregion

#region Длительная фаза и расчёт
## Продолжение той же фазы не создаёт новый визит и не повторяет оплату выданного заказа.
func test_long_phase_keeps_one_visit_and_one_payment() -> void:
	var body: E_DistrictNpc = _stage(0)
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var visit: CustomerVisit = _service(body, "long_phase")
	visit.payment = 100
	var ready: PackageDeliveryCheck = PackageDeliveryCheck.new()
	ready.result = PackageDeliveryCheck.Result.READY
	assert_true(CustomerOutcomeService.receive(visit, ready))
	assert_true(CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.TAKEN))
	var wallet: C_Wallet = C_Wallet.new()
	CustomerOutcomeService.settle(visit, wallet, cycle.day_index)
	NpcServiceRole.finish_appearance(body, visit)
	var flow: C_CustomerFlow = CustomerFlowService.current()
	for repeat_index: int in 3:
		assert_false(NpcServiceRole.enqueue_next(flow, cycle))
		_run_tree(body, NpcBrainService.TREE_PATH, _district.definition.service_wait_timeout + 1.0)
		CustomerOutcomeService.settle(visit, wallet, cycle.day_index)
		assert_false(CustomerOutcomeService.receive(visit, ready))
	assert_eq(flow.visits.size(), 1)
	assert_eq(wallet.balance, 100)
	assert_eq(wallet.operations.size(), 1)
	assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_false(body.has_component(C_CustomerAgent))
#endregion
