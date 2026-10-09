extends RefCounted
## Explicit live target/weapon bindings and start/cancel/hit commands; Systems own combat clocks.
class_name CombatService


#region Противник и завершение боя
## Повторная та же цель идемпотентна; смена завершает прежнее действие перед новой связью.
static func bind_target(actor: Entity, target: Entity) -> bool:
	if not GrabQueries.holder_available(actor) or not GrabQueries.holder_available(target) or actor == target:
		return false
	if CombatQueries.target_for(actor) == target:
		return true

	end_combat(actor)
	actor.add_relationship(Relationship.new(R_CombatTarget.new(), target))
	return true


## Отменяет удар и атаку NPC, снимает цель и останавливает боевое намерение.
static func end_combat(actor: Entity) -> void:
	if not is_instance_valid(actor):
		return

	cancel_strike(actor)
	NpcAttackExecutionService.cancel(actor)
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation is R_CombatTarget:
			actor.remove_relationship(relation)
	if actor.has_component(C_NpcIntent):
		NpcIntentService.stop(actor)
		NpcIntentService.look_along_movement(actor)


#endregion

#region Удар игрока
## Проверяет готовность игрока и настоящее оружие в его руках.
static func can_strike(actor: Entity, weapon: Entity) -> bool:
	if not GrabQueries.holder_available(actor) or not GrabQueries.entity_available(weapon):
		return false

	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	var config: C_MeleeWeapon = weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	var grip: Relationship = GrabQueries.held_relationship(weapon)
	return state != null and state.phase == C_Combat.Phase.READY and config != null and config.attack != null and grip != null and grip.target == actor


## Фиксирует удар/оружие один раз, запускает визуальный замах и слышимый шум.
static func start_strike(actor: Entity, weapon: Entity) -> bool:
	if not can_strike(actor, weapon):
		return false

	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	state.execution_generation += 1
	state.strike = (weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon).attack
	state.phase = C_Combat.Phase.WINDUP
	state.elapsed = 0.0
	state.hit_committed = false
	actor.add_relationship(Relationship.new(R_AttackWeapon.new(), weapon))
	MeleeWeaponPresentation.start(weapon)
	var district: C_District = NpcPopulationQueries.current()
	if district != null:
		NpcPerceptionService.action_noise(actor, district.definition.strike_noise_radius)
	return true


## Запрашивает ближний урон с множителем голода; здоровье меняет O_Damage.
static func hit(actor: Entity, source: Entity, target: Entity, damage: float) -> bool:
	if not GrabQueries.holder_available(actor) or not GrabQueries.holder_available(target) or actor == target:
		return false
	if actor.has_component(C_NoDamage):
		return false

	var held: Relationship = GrabQueries.held_relationship(target)
	if held != null and held.target == actor:
		return false

	var request: DamageRequest = DamageRequest.new()
	request.source = source
	request.instigator = actor
	request.target = target
	request.amount = damage * HungerRules.damage_multiplier(actor.get_component(C_Hunger) as C_Hunger)
	request.damage_type = DamageRequest.Type.MELEE
	return DamageRequestService.submit(request)


## Очищает бой недоступного участника и противников, связанных с ним.
static func entity_unavailable(actor: Entity) -> void:
	end_combat(actor)
	if not is_instance_valid(ECS.world):
		return

	for opponent: Entity in ECS.world.query.with_all([C_NpcCombat]).execute():
		if CombatQueries.target_for(opponent) == actor:
			end_combat(opponent)


#endregion

#region Геометрия и очистка удара


## Reads the optional live weapon binding of the current strike.
static func weapon_for(actor: Entity) -> Entity:
	for relation: Relationship in actor.relationships:
		if relation.relation is R_AttackWeapon:
			return relation.target as Entity if is_instance_valid(relation.target) else null
	return null


## Cancels one strike and invalidates queued clock work without applying another hit.
static func cancel_strike(actor: Entity) -> void:
	MeleeWeaponPresentation.reset(weapon_for(actor))
	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	if state != null:
		state.execution_generation += 1
		state.phase = C_Combat.Phase.READY
		state.elapsed = 0.0
		state.strike = null
		state.hit_committed = false
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation is R_AttackWeapon:
			actor.remove_relationship(relation)

#endregion
