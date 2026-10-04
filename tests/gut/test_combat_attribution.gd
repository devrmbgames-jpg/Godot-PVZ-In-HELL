extends GutTest
## Проверяет причину боя по живым связям и постоянным ID истории жалоб.

var _world: World = null
var _player: Entity = null
var _customer: Entity = null
var _visit: CustomerVisit = null
var _flow: C_CustomerFlow = null
var _cycle: C_DayCycle = null


#region Окружение живых участников
## Создаёт игрока и клиента с постоянным заказом и боевыми компонентами.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_Damage.new())
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new()]
	_world.add_entity(session)
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.day_index = 2
	_player = Entity.new()
	_player.component_resources = [C_PlayerInputController.new(), C_Living.new()]
	_world.add_entity(_player)
	_customer = Entity.new()

	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = &"visit/current"
	_customer.component_resources = [agent, C_Living.new(), C_NpcCombat.new(), C_Health.new()]
	_world.add_entity(_customer)
	_visit = CustomerVisit.new()
	_visit.visit_id = agent.visit_id
	_visit.customer_id = &"same-customer"
	_visit.definition = DEF_Customer.new()
	_flow.visits = [_visit]


## Удаляет World и очищает ссылки участников и визита.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null
	_world = null
	_player = null
	_customer = null
	_visit = null
	_flow = null
	_cycle = null


func _request(actor: Entity, target: Entity) -> DamageRequest:
	var request: DamageRequest = DamageRequest.new()
	request.source = actor
	request.instigator = actor
	request.target = target
	request.damage_type = DamageRequest.Type.MELEE
	return request


#endregion

#region Причина боя и постоянная история
## Самооборона определяется текущей живой целью NPC, а не сохраняется после завершения боя.
func test_unprovoked_attack_and_self_defense_use_live_opponent_binding() -> void:
	var context: CombatContext = CombatAttribution.describe(_request(_player, _customer))
	assert_eq(context.reason, CombatContext.Reason.ORDINARY_ATTACK)
	assert_eq(context.customer_id, _visit.customer_id)
	assert_true(CombatService.bind_target(_customer, _player))
	context = CombatAttribution.describe(_request(_player, _customer))
	assert_eq(context.reason, CombatContext.Reason.SELF_DEFENSE)
	CombatService.end_combat(_customer)
	context = CombatAttribution.describe(_request(_player, _customer))
	assert_eq(context.reason, CombatContext.Reason.ORDINARY_ATTACK)


## Мошенничество и нарушение испытания передают разные типизированные причины урона NPC.
func test_fraud_and_challenge_escalation_are_typed_npc_damage_reasons() -> void:
	var state: C_NpcCombat = _customer.get_component(C_NpcCombat) as C_NpcCombat
	state.aggression_reason = CombatContext.Reason.FRAUD_ESCALATION
	assert_eq(CombatAttribution.describe(_request(_customer, _player)).reason, CombatContext.Reason.FRAUD_ESCALATION)
	state.aggression_reason = CombatContext.Reason.CHALLENGE_ESCALATION
	assert_eq(CombatAttribution.describe(_request(_customer, _player)).reason, CombatContext.Reason.CHALLENGE_ESCALATION)


## История ложной жалобы даёт окно мести тому же постоянному клиенту ровно на семь дней.
func test_persisted_false_complaint_allows_same_customer_for_exactly_seven_days() -> void:
	var previous: CustomerVisit = CustomerVisit.new()
	previous.customer_id = _visit.customer_id
	previous.definition = DEF_Customer.new()
	previous.started = true
	previous.finished = true
	previous.actual = CustomerVisit.Actual.DELIVERED
	previous.complaint_roll = 0.0
	assert_true(CustomerOutcomeService.create_complaint(previous, 1, CustomerComplaint.Reason.NOT_DELIVERED, true))
	CustomerOutcomeService.resolve_complaint(previous, C_Wallet.new(), 2)
	assert_eq(previous.complaint.outcome, CustomerComplaint.Outcome.FALSE_CLAIM)
	_flow.visits.append(previous)
	assert_eq(CombatAttribution.describe(_request(_player, _customer)).reason, CombatContext.Reason.JUSTIFIED_RETALIATION)
	_cycle.day_index = 8
	assert_eq(CombatAttribution.describe(_request(_player, _customer)).reason, CombatContext.Reason.JUSTIFIED_RETALIATION)
	_cycle.day_index = 9
	assert_eq(CombatAttribution.describe(_request(_player, _customer)).reason, CombatContext.Reason.ORDINARY_ATTACK)
	_cycle.day_index = 3
	_visit.customer_id = &"different-customer"
	assert_eq(CombatAttribution.describe(_request(_player, _customer)).reason, CombatContext.Reason.ORDINARY_ATTACK)


## Удар удерживаемым предметом получает владельца хвата; снимок контекста переживает удаление участника.
func test_held_impact_attribution_is_actor_and_snapshot_has_no_live_reference() -> void:
	var prop: Entity = Entity.new()
	_world.add_entity(prop)
	prop.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	var request: DamageRequest = _request(_player, _customer)
	request.source = prop
	request.instigator = null
	request.damage_type = DamageRequest.Type.IMPACT

	var context: CombatContext = CombatAttribution.describe(request)
	assert_eq(request.instigator, _player)
	assert_true(context.actor_is_player)
	assert_eq(context.customer_id, _visit.customer_id)
	var saved: CombatContext = context.duplicate(true) as CombatContext
	_world.remove_entity(_player)
	_player = null
	assert_true(saved.actor_is_player)
	assert_eq(saved.visit_id, _visit.visit_id)

#endregion
