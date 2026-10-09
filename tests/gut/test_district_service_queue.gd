extends "res://tests/gut/test_district_plan_acceptance.gd"
## Регрессии подготовки соседних клиентов и светобоязненного последнего визита.

#region Очередь района
## Смерть огненного получателя снимает настоящую ауру и освобождает стойку без ложной выдачи.
func test_fire_customer_death_releases_aura_and_counter() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	_district.definition.service_transfer_pause = 0.0
	_world.add_observer(O_HazardSpawn.new())
	_world.add_system(S_HazardFollow.new())
	var fire_body: E_DistrictNpc = _stage(1)
	var fire_person: NpcRecord = _district.people[1]
	fire_person.profile.rules = [load("res://content/domains/npc/definitions/def_npc_trait_2.tres") as DEF_NpcTrait]
	var next_body: E_DistrictNpc = _stage(3, Vector3(10, 0, 0))
	var first: CustomerVisit = _case(fire_person, "fire_death")
	var next: CustomerVisit = _case(_district.people[3], "after_fire_death")
	NpcServiceRole.begin(fire_body, fire_person, first, cycle.day_index)
	NpcServiceRole.begin(next_body, _district.people[3], next, cycle.day_index)
	NpcServiceRole.claim_counter(fire_body)
	NpcAiFixture.traits(fire_body, fire_person, null, 0.2)
	_world.process(0.0)
	var effects: Array = _world.query.with_all([C_Hazard, C_ToxicArea]).execute()
	assert_eq(effects.size(), 1, "A real fire aura exists before death")
	if effects.is_empty():
		return
	var aura: Entity = effects[0] as Entity
	assert_same(HazardFollowService.binding(aura).target, fire_body)
	assert_false(NpcServiceRole.can_approach(next_body))

	fire_body.add_component(C_Death.new())
	DistrictPopulationService.mark_dead(fire_person, fire_body, cycle.day_index)
	_world.process(0.0)
	assert_true(_world.query.with_all([C_Hazard, C_ToxicArea]).execute().is_empty())
	assert_true(aura.is_queued_for_deletion())
	assert_false(fire_body.has_component(C_CustomerAgent))
	assert_eq(fire_body.get_relationships(Relationship.new(R_NpcServiceAt.new(), CustomerFlowQueries.counter())).size(), 0)
	assert_true(first.customer_dead)
	assert_eq(first.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(first.declaration, CustomerVisit.Declaration.NONE)
	assert_true(NpcServiceRole.can_approach(next_body))
	NpcServiceRole.claim_counter(next_body)
	assert_eq((next_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.APPROACHING)

## Ожидание выключателя снаружи не резервирует стойку для всех остальных жителей.
func test_light_wait_keeps_counter_available_for_next_recipient() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var waiting: E_DistrictNpc = _stage(6)
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	_district.people[6].profile.rules = [rule]
	var zone: NpcLightZone = _light_zone()
	var first: CustomerVisit = _case(_district.people[6], "light_outside")
	var next: CustomerVisit = _case(_district.people[3], "next_inside")
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	NpcServiceRole.enqueue_next(flow, cycle)
	NpcServiceRole.enqueue_next(flow, cycle)
	NpcServiceRole.claim_counter(waiting)
	var next_body: E_DistrictNpc = NpcPopulationQueries.body_for(next.customer_id)
	assert_eq((waiting.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	assert_eq(waiting.get_relationships(Relationship.new(R_NpcServiceAt.new(), CustomerFlowQueries.counter())).size(), 0)
	assert_true(NpcServiceRole.can_approach(next_body))
	NpcServiceRole.claim_counter(next_body)
	zone.enabled = false
	_run_branch(waiting, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_eq((waiting.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	NpcServiceRole.finish_appearance(next_body, next)
	flow.arrival_cooldown_seconds = 0.0
	_run_branch(waiting, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_eq((waiting.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.APPROACHING)
	assert_true(first.started)
	var third: CustomerVisit = _case(_district.people[4], "light_wait_third")
	var fourth: CustomerVisit = _case(_district.people[5], "light_wait_fourth")
	NpcServiceRole.claim_counter(waiting)
	zone.enabled = true
	(waiting.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_DARKNESS
	for link: Relationship in waiting.relationships.duplicate():
		if link.relation is R_NpcServiceAt:
			waiting.remove_relationship(link)
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(third.started)
	assert_true(fourth.started)
	var fifth: CustomerVisit = _case(_district.people[0], "light_wait_fifth")
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(fifth.started)
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 4)
## Наследуемая длинная пауза потока не задерживает уже подготовленного жителя.
func test_prepared_recipient_uses_short_district_pause() -> void:
	# Other inherited fixtures disable this authored pause; this regression needs a positive interval.
	var configured_pause: float = _district.definition.service_transfer_pause
	const SHORT_SERVICE_PAUSE_SECONDS: float = 0.25
	_district.definition.service_transfer_pause = SHORT_SERVICE_PAUSE_SECONDS
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 120.0
	var first: CustomerVisit = _case(_district.people[0], "pause_first")
	var next: CustomerVisit = _case(_district.people[3], "pause_next")
	NpcServiceRole.enqueue_next(flow, cycle)
	NpcServiceRole.enqueue_next(flow, cycle)
	var first_body: E_DistrictNpc = NpcPopulationQueries.body_for(first.customer_id)
	var next_body: E_DistrictNpc = NpcPopulationQueries.body_for(next.customer_id)
	NpcServiceRole.claim_counter(first_body)
	NpcServiceRole.finish_appearance(first_body, first)
	assert_eq(flow.arrival_cooldown_seconds, _district.definition.service_transfer_pause)
	assert_false(NpcServiceRole.can_approach(next_body))
	flow.arrival_cooldown_seconds = 0.0
	assert_true(NpcServiceRole.can_approach(next_body))
	_district.definition.service_transfer_pause = configured_pause

## Три разные личности готовятся заранее, четвёртая и второй заказ того же NPC ждут.
func test_preparation_keeps_two_next_distinct_recipients() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	var first: CustomerVisit = _case(_district.people[0], "ready_one")
	var same: CustomerVisit = _case(_district.people[0], "ready_same_person")
	var second: CustomerVisit = _case(_district.people[3], "ready_two")
	var third: CustomerVisit = _case(_district.people[4], "ready_three")
	var fourth: CustomerVisit = _case(_district.people[5], "ready_four")
	for attempt: int in 3:
		assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(first.started)
	assert_true(second.started)
	assert_true(third.started)
	assert_false(same.started)
	assert_false(fourth.started)
	assert_false(NpcServiceRole.enqueue_next(flow, cycle))
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 3)

## Если свет не выключили, реальное дерево завершает ожидание и сохраняет следующий приход.
func test_native_light_wait_defers_once_and_releases_counter() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(6)
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	_district.people[6].profile.rules = [rule]
	var zone: NpcLightZone = _light_zone()
	assert_true(zone.is_logically_lit())
	var visit: CustomerVisit = _case(_district.people[6], "wait_light")
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	var service: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(service.phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	body.place_at(CustomerFlowQueries.counter().entry_position())
	_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_true(service.light_warning_started)
	assert_eq(service.phase, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	service.entrance_wait_elapsed = _district.definition.service_wait_timeout
	_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(visit.deferred_day, 2)
	assert_eq(visit.next_followup_day, 3)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(CustomerFlowQueries.actionable_remaining(flow, 2), 0)
	assert_true(DayPhaseService.finish_blockers(cycle).is_empty())
	assert_false(NpcServiceRole.enqueue_next(flow, cycle))

## Выключенный свет разрешает вход, включение внутри прерывает роль для укрытия.
func test_native_light_wait_resumes_and_inside_light_requests_refuge() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var body: E_DistrictNpc = _stage(6)
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.kind = DEF_NpcTrait.Kind.LIGHT_AVERSION
	_district.people[6].profile.rules = [rule]
	var zone: NpcLightZone = _light_zone()
	var visit: CustomerVisit = _case(_district.people[6], "switch_light")
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	NpcServiceRole.enqueue_next(flow, cycle)
	_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	zone.enabled = false
	_run_branch(body, C_NpcDecision.Owner.SERVICE, 0.2)
	var service: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(service.phase, C_CustomerAgent.Phase.APPROACHING)
	service.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	zone.enabled = true
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.light_distress = true
	_run_tree(body, CustomerNpcLifecycleBinding.TREE_PATH, 0.2)
	assert_eq((body.get_component(C_NpcDecision) as C_NpcDecision).intent_owner, C_NpcDecision.Owner.EMERGENCY)
	assert_eq((body.get_component(C_NpcIntent) as C_NpcIntent).move_position, NpcTraitService.dark_refuge(body, _district.people[6]))
	CustomerRoleInterruptionService.suspend(body)
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
## Зарегистрированный светобоязненный получатель получает роль даже при включённом свете.
func test_day_two_light_averse_recipient_is_not_silently_skipped() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.DAY
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	_light_zone()
	var visit: CustomerVisit = _case(_district.people[6], "day_two_light")
	assert_eq(CustomerFlowQueries.actionable_remaining(flow, 2), 1)
	assert_true(NpcServiceRole.enqueue_next(flow, cycle), "Lit service desk must not silently skip its required recipient")
	assert_true(visit.started)
#endregion


#region Реакции и воспринимаемая опасность
## Подчинение не является угрозой трусливому собеседнику.
func test_timid_submission_does_not_attack_or_flee() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile = person.profile.duplicate() as DEF_NpcProfile
	person.profile.personality = DEF_NpcProfile.Personality.TIMID
	person.profile.timid_flee_probability = 1.0
	var player: E_DistrictNpc = _player(Vector3(0, 0, -2))
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.SUBMISSION, &"submission"), NpcMemory.Reaction.TALK)
	assert_false((body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing)
	assert_null(CombatQueries.target_for(body))

## Обычная угроза не обращает здорового агрессивного NPC в бегство; голод 80% ещё не хищный.
func test_aggressive_fear_requires_visible_predatory_hunger_above_eighty() -> void:
	var body: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.profile = person.profile.duplicate() as DEF_NpcProfile
	person.profile.personality = DEF_NpcProfile.Personality.AGGRESSIVE
	person.profile.high_attack_probability = 0.0
	person.profile.low_flee_probability = 1.0
	var player: E_DistrictNpc = _player(Vector3(0, 0, -2))
	var hunger: C_Hunger = C_Hunger.new()
	hunger.policy = DEF_HungerPolicy.new()
	player.add_component(hunger)
	hunger = player.get_component(C_Hunger) as C_Hunger
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.player_visible = true
	for value: float in [30.0, 80.0]:
		hunger.value = value
		assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, StringName("threat/%d" % int(value))), NpcMemory.Reaction.TALK)
		assert_false(awareness.fleeing)
	hunger.value = 81.0
	awareness.player_visible = false
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"hidden_hunger"), NpcMemory.Reaction.TALK)
	awareness.player_visible = true
	assert_eq(NpcSocialService.react(body, player, NpcMemory.Kind.THREAT, &"visible_hunger"), NpcMemory.Reaction.FLEE)
	assert_null(CombatQueries.target_for(body))
#endregion

#region Initial role action capability
## Entering/leaving a visit changes transient role state, never the compiled action capability.
func test_service_role_keeps_initial_actions_and_inactive_choices_hidden() -> void:
	var person: NpcRecord = _district.people[3]
	var body: E_DistrictNpc = _stage(3)
	var actions: C_InteractionActionSet = body.get_component(C_InteractionActionSet) \
		as C_InteractionActionSet
	var initial_actions: Array[DEF_InteractionAction] = actions.actions.duplicate()
	assert_false(body.has_component(C_CustomerAgent))
	assert_true(initial_actions[0] is DEF_CustomerAction)
	assert_true(initial_actions[1] is DEF_CustomerHandoffAction)
	assert_false(initial_actions[0].is_available(body, body, null))
	assert_false(initial_actions[1].is_available(body, body, null))

	var visit: CustomerVisit = _case(person, "prepared-role-actions")
	NpcServiceRole.begin(body, person, visit, DayPhaseQueries.current().day_index)
	assert_true(body.has_component(C_CustomerAgent))
	assert_same(body.get_component(C_InteractionActionSet), actions)
	assert_eq(actions.actions, initial_actions)
	NpcServiceRole.release(body, visit.visit_id)
	assert_false(body.has_component(C_CustomerAgent))
	assert_same(body.get_component(C_InteractionActionSet), actions)
	assert_eq(actions.actions, initial_actions)
#endregion
