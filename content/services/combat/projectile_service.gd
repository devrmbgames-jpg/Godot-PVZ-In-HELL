extends RefCounted
## Прямой полёт с лучом по пройденному отрезку каждого такта и одним запросом урона.
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
	state.damage = attack.damage * HungerService.damage_multiplier(actor.get_component(C_Hunger) as C_Hunger)
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


## Проверяет луч всего шага до записи позиции; первый контакт или истечение удаляют снаряд.
static func tick(projectile: Entity, delta: float) -> void:
	if not EntityAvailability.contains(projectile, ECS.world):
		return

	var state: C_CombatProjectile = projectile.get_component(C_CombatProjectile) as C_CombatProjectile
	var node: Node3D = projectile as Node as Node3D
	if state == null or node == null:
		return

	var travel_seconds: float = minf(maxf(0.0, delta), state.remaining_seconds)
	var destination: Vector3 = node.global_position + state.velocity * travel_seconds
	var actor: Entity = _source_for(projectile)
	var exclude: Array[RID] = []
	if actor != null:
		exclude = CombatGeometry.exclusions(actor)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(node.global_position, destination, state.collision_mask, exclude)
	var hit: Dictionary = node.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Entity = hit.get("collider") as Node as Entity
		if target != null and target != actor and target.has_component(C_Health):
			var request: DamageRequest = DamageRequest.new()
			request.source = projectile
			request.instigator = actor
			request.instigator_id = state.instigator_id
			request.target = target
			request.amount = state.damage
			request.damage_type = DamageRequest.Type.PROJECTILE
			request.combat_context = state.attribution
			DamageRequestService.submit(request)
		ECS.world.remove_entity(projectile)
		return

	node.global_position = destination
	state.remaining_seconds -= travel_seconds
	if state.remaining_seconds <= 0.0:
		ECS.world.remove_entity(projectile)


static func _source_for(projectile: Entity) -> Entity:
	for relation: Relationship in projectile.relationships:
		if relation.relation is R_ProjectileSource:
			return relation.target as Entity if is_instance_valid(relation.target) else null
	return null
