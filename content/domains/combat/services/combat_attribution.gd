extends RefCounted
## Собирает постоянный контекст конкретного запроса боя из текущих фактов участников.
class_name CombatAttribution


## Создаёт контекст melee/impact/projectile; при распознавании дополняет instigator запроса.
static func describe(request: DamageRequest) -> CombatContext:
	if request.damage_type not in [DamageRequest.Type.MELEE, DamageRequest.Type.IMPACT, DamageRequest.Type.PROJECTILE]:
		return null

	var actor: Entity = request.instigator
	if not is_instance_valid(actor):
		var grip: Relationship = GrabQueries.held_relationship(request.source)
		actor = grip.target as Entity if grip != null else request.source
	if not is_instance_valid(actor) or not actor.has_component(C_Living):
		return null

	request.instigator = actor
	var context: CombatContext = CombatContext.new()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	context.day = cycle.day_index if cycle != null else 0
	context.actor_is_player = actor.has_component(C_PlayerInputController)
	var customer: Entity = request.target if context.actor_is_player else actor
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id) if agent != null else null
	if visit != null:
		context.customer_id = visit.customer_id
		context.visit_id = visit.visit_id

	var combat: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if not context.actor_is_player and combat != null:
		context.reason = combat.aggression_reason
	elif context.actor_is_player:
		if retaliation_allowed(context.customer_id, context.day):
			context.reason = CombatContext.Reason.JUSTIFIED_RETALIATION
		elif CombatQueries.target_for(customer) == actor:
			context.reason = CombatContext.Reason.SELF_DEFENSE

	var weapon: C_MeleeWeapon = request.source.get_component(C_MeleeWeapon) as C_MeleeWeapon if is_instance_valid(request.source) else null
	if weapon != null and weapon.attack != null:
		context.weapon_key = weapon.attack.key
	return context


## Проверяет сохранённые визиты личности, включая отсутствующего сейчас участника.
static func retaliation_allowed(customer_id: StringName, day: int) -> bool:
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	if flow == null or customer_id == &"":
		return false

	for visit: CustomerVisit in flow.visits:
		if visit.customer_id == customer_id and CustomerOutcomeService.retaliation_allowed(visit, day):
			return true
	return false
