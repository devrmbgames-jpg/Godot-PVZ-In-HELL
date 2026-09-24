extends RefCounted
## Single radial blast calculation shared by generic explosion producers; no package knowledge.
class_name ExplosionResolver


## Called once at the physics System command boundary, after the one-shot guard is committed.
static func resolve(entity: Entity, hazard: C_Hazard, world: World) -> void:
	if not EntityAvailability.contains(entity, world):
		return

	var effect: E_Explosion = entity as E_Explosion
	var profile: DEF_Explosion = hazard.definition as DEF_Explosion
	if effect == null or profile == null:
		return

	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = profile.radius
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis.IDENTITY, effect.spatial.global_position)
	shape_query.collision_mask = profile.collision_mask
	shape_query.collide_with_areas = false
	var space: PhysicsDirectSpaceState3D = effect.spatial.get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(shape_query, profile.maximum_targets)
	var hits: Dictionary[int, BlastHit] = { }
	for overlap: Dictionary in overlaps:
		_collect_hit(overlap, effect.spatial.global_position, profile.radius, hits)

	var origin: Entity = hazard.origin if is_instance_valid(hazard.origin) else null
	var origin_exclusions: Array[RID] = _origin_exclusions(origin)

	# One representative point/ray per Entity (or standalone body), nearest shape center wins.
	for hit: BlastHit in hits.values():
		if not is_instance_valid(hit.body) or hit.body.is_queued_for_deletion():
			continue

		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			effect.spatial.global_position,
			hit.point,
			profile.obstacle_mask,
		)
		var exclusions: Array[RID] = origin_exclusions.duplicate()
		exclusions.append(hit.body.get_rid())
		ray.exclude = exclusions
		ray.hit_from_inside = true
		if not hit.point.is_equal_approx(effect.spatial.global_position):
			if not space.intersect_ray(ray).is_empty():
				continue

		var weight: float = pow(hit.weight, profile.falloff_power)
		var rigid: RigidBody3D = hit.body as RigidBody3D
		if rigid != null and not rigid.freeze and profile.impulse > 0.0:
			var direction: Vector3 = (hit.point - effect.spatial.global_position).normalized()
			if direction.is_zero_approx():
				direction = Vector3.UP
			rigid.apply_central_impulse(direction * profile.impulse * weight)

		if EntityAvailability.contains(hit.target, world) and hit.target.has_component(C_Health):
			HazardDamage.submit(
				entity,
				hazard,
				hit.target,
				profile.damage * weight,
				DamageRequest.Type.EXPLOSION,
			)


static func _origin_exclusions(origin: Entity) -> Array[RID]:
	var exclusions: Array[RID] = []
	if not is_instance_valid(origin):
		return exclusions

	var root_body: PhysicsBody3D = origin as Node as PhysicsBody3D
	if root_body != null:
		exclusions.append(root_body.get_rid())

	# Rare boundary traversal supports authored child bodies without retaining physics handles.
	for body: PhysicsBody3D in origin.find_children("*", "PhysicsBody3D", true, false):
		exclusions.append(body.get_rid())

	return exclusions


static func _collect_hit(
	overlap: Dictionary,
	center: Vector3,
	radius: float,
	hits: Dictionary[int, BlastHit],
) -> void:
	var body: PhysicsBody3D = overlap.get("collider") as PhysicsBody3D
	if not is_instance_valid(body):
		return

	var target: Entity = HazardTargets.entity_for(body)
	var has_health: bool = is_instance_valid(target) and target.has_component(C_Health)
	if not has_health and not body is RigidBody3D:
		return

	var point: Vector3 = body.global_position
	var shape_index: int = int(overlap.get("shape", 0))
	var shape_owner: Object = body.shape_owner_get_owner(body.shape_find_owner(shape_index))
	if shape_owner is Node3D:
		var shape_node: Node3D = shape_owner as Node3D
		point = shape_node.global_position

	var weight: float = clampf(1.0 - center.distance_to(point) / radius, 0.0, 1.0)
	if weight <= 0.0:
		return

	var key: int = target.get_instance_id() if is_instance_valid(target) else body.get_instance_id()
	if hits.has(key) and hits[key].weight >= weight:
		return

	var hit: BlastHit = BlastHit.new()
	hit.body = body
	hit.target = target
	hit.point = point
	hit.weight = weight
	hits[key] = hit


## Resolution-local immutable candidate snapshot; never persisted or attached as ECS state.
class BlastHit extends RefCounted:
	var body: PhysicsBody3D = null
	var target: Entity = null
	var point: Vector3 = Vector3.ZERO
	var weight: float = 0.0
