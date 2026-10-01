extends RefCounted
## Live opponent binding and Player weapon strikes. NPC execution is NpcAttackService.
class_name CombatService


static func target_for(actor: Entity) -> Entity:
	if not is_instance_valid(actor):
		return null
	for relation: Relationship in actor.relationships:
		if relation.relation is R_CombatTarget:
			return relation.target as Entity if is_instance_valid(relation.target) else null
	return null


static func bind_target(actor: Entity, target: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.holder_available(target) or actor == target:
		return false
	if target_for(actor) == target:
		return true
	end_combat(actor)
	actor.add_relationship(Relationship.new(R_CombatTarget.new(), target))
	return true


static func end_combat(actor: Entity) -> void:
	if not is_instance_valid(actor):
		return
	_cancel_strike(actor)
	NpcAttackService.cancel(actor)
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation is R_CombatTarget:
			actor.remove_relationship(relation)
	if actor.has_component(C_NpcIntent):
		NpcIntentService.stop(actor)
		NpcIntentService.look_along_movement(actor)


static func can_strike(actor: Entity, weapon: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(weapon):
		return false
	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	var config: C_MeleeWeapon = weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon
	var grip: Relationship = GrabService.held_relationship(weapon)
	return state != null and state.phase == C_Combat.Phase.READY and config != null and config.attack != null and grip != null and grip.target == actor


static func start_strike(actor: Entity, weapon: Entity) -> bool:
	if not can_strike(actor, weapon):
		return false
	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	state.strike = (weapon.get_component(C_MeleeWeapon) as C_MeleeWeapon).attack
	state.phase = C_Combat.Phase.WINDUP
	state.elapsed = 0.0
	state.hit_committed = false
	actor.add_relationship(Relationship.new(R_AttackWeapon.new(), weapon))
	return true


static func tick_strike(actor: Entity, delta: float) -> void:
	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	if state == null or state.phase == C_Combat.Phase.READY:
		return
	var weapon: Entity = _weapon_for(actor)
	var grip: Relationship = GrabService.held_relationship(weapon)
	if not GrabService.holder_available(actor) or grip == null or grip.target != actor or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PROLONGED:
		_cancel_strike(actor)
		return
	var previous: float = state.elapsed
	state.elapsed += maxf(0.0, delta)
	var attack: DEF_MeleeAttack = state.strike
	var active_end: float = attack.windup_seconds + attack.active_seconds
	if state.elapsed >= attack.windup_seconds and previous < active_end and not state.hit_committed:
		_scan_strike(actor, weapon, state)
	if state.elapsed >= active_end + attack.recovery_seconds:
		_cancel_strike(actor)
	elif state.elapsed >= active_end:
		state.phase = C_Combat.Phase.RECOVERY
	elif state.elapsed >= attack.windup_seconds:
		state.phase = C_Combat.Phase.ACTIVE


static func hit(actor: Entity, source: Entity, target: Entity, damage: float) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.holder_available(target) or actor == target:
		return false
	if actor.has_component(C_NoDamage):
		return false
	var held: Relationship = GrabService.held_relationship(target)
	if held != null and held.target == actor:
		return false
	var request: DamageRequest = DamageRequest.new()
	request.source = source
	request.instigator = actor
	request.target = target
	request.amount = damage
	request.damage_type = DamageRequest.Type.MELEE
	return DamageRequestService.submit(request)


static func entity_unavailable(actor: Entity) -> void:
	end_combat(actor)
	if not is_instance_valid(ECS.world):
		return
	for opponent: Entity in ECS.world.query.with_all([C_NpcCombat]).execute():
		if target_for(opponent) == actor:
			end_combat(opponent)


static func _scan_strike(actor: Entity, weapon: Entity, state: C_Combat) -> void:
	var node: Node3D = actor as Node as Node3D
	if node == null or not node.is_inside_tree():
		return
	var attack: DEF_MeleeAttack = state.strike
	var closest: Entity = null
	var distance: float = INF
	# The warehouse has many adjacent static tiles. A capped overlap query can
	# return only scenery and omit an opponent; health owners are the candidate set.
	for target: Entity in ECS.world.query.with_all([C_Health]).execute():
		if target == actor or not (target as Node) is PhysicsBody3D or not GrabService.holder_available(target):
			continue
		if not CombatGeometry.in_cone(actor, target, attack.reach, attack.half_angle_degrees) or not CombatGeometry.clear_line(actor, target, attack.collision_mask):
			continue
		var candidate: float = CombatGeometry.origin(actor).distance_squared_to(CombatGeometry.aim_point(target))
		if candidate < distance:
			closest = target
			distance = candidate
	if closest != null:
		state.hit_committed = hit(actor, weapon, closest, attack.damage)


static func _weapon_for(actor: Entity) -> Entity:
	for relation: Relationship in actor.relationships:
		if relation.relation is R_AttackWeapon:
			return relation.target as Entity if is_instance_valid(relation.target) else null
	return null


static func _cancel_strike(actor: Entity) -> void:
	var state: C_Combat = actor.get_component(C_Combat) as C_Combat
	if state != null:
		state.phase = C_Combat.Phase.READY
		state.elapsed = 0.0
		state.strike = null
		state.hit_committed = false
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation is R_AttackWeapon:
			actor.remove_relationship(relation)
