extends RefCounted
## Explicit nonphysical projectile factory with launch attribution; flight belongs to S_CombatProjectile.
class_name ProjectileService

const PROJECTILE_SCENE: PackedScene = preload("res://content/entities/combat/combat_projectile.tscn")


## Создаёт нефизический снаряд, фиксируя скорость, урон, источник и контекст запуска.
static func launch(actor: Entity, target: Entity, attack: DEF_NpcAttack) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.holder_available(target) or not is_instance_valid(ECS.world):
		return false

	var projectile: Entity = PROJECTILE_SCENE.instantiate() as Entity
	ECS.world.add_entity(projectile)
	if actor.has_component(C_NoDamage):
		projectile.add_component(C_NoDamage.new())
	var node: Node3D = projectile as Node as Node3D
	node.global_position = CombatGeometry.origin(actor)
	var state: C_CombatProjectile = projectile.get_component(C_CombatProjectile) as C_CombatProjectile
	state.velocity = node.global_position.direction_to(CombatGeometry.aim_point(target)) * attack.projectile_speed
	state.remaining_seconds = attack.projectile_lifetime
	state.damage = attack.damage * HungerRules.damage_multiplier(actor.get_component(C_Hunger) as C_Hunger)
	state.collision_mask = attack.collision_mask

	var request: DamageRequest = DamageRequest.new()
	request.instigator = actor
	request.source = actor
	request.target = target
	request.damage_type = DamageRequest.Type.PROJECTILE
	state.attribution = CombatAttribution.describe(request)
	state.instigator_id = actor.id
	projectile.add_relationship(Relationship.new(R_ProjectileSource.new(), actor))
	return true
