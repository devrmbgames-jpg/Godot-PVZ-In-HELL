extends RefCounted
## Общий однократный радиальный расчёт взрыва без знания о посылках.
class_name ExplosionResolver


#region Однократный радиальный расчёт
## Вызывается на границе CommandBuffer после фиксации защиты однократного эффекта.
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
	shape_query.transform = Transform3D(Basis.IDENTITY, effect.get_spatial().global_position)
	shape_query.collision_mask = profile.target_mask
	shape_query.collide_with_areas = false
	var space: PhysicsDirectSpaceState3D = effect.get_spatial().get_world_3d().direct_space_state
	var overlaps: Array[Dictionary] = space.intersect_shape(shape_query, profile.maximum_targets)
	var hits: Dictionary[int, BlastHit] = { }
	for overlap: Dictionary in overlaps:
		_collect_hit(overlap, effect.get_spatial().global_position, profile.radius, hits)

	var origin: Entity = hazard.origin if is_instance_valid(hazard.origin) else null
	var origin_exclusions: Array[RID] = _origin_exclusions(origin)

	# Одна точка/луч на Entity или отдельное тело; выбирается ближайший центр формы.
	for hit: BlastHit in hits.values():
		if not is_instance_valid(hit.body) or hit.body.is_queued_for_deletion():
			continue

		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			effect.get_spatial().global_position,
			hit.point,
			profile.obstacle_mask,
		)
		var exclusions: Array[RID] = origin_exclusions.duplicate()
		exclusions.append(hit.body.get_rid())
		ray.exclude = exclusions
		# Взрыв у пола не скрывается самим началом луча внутри окружения;
		# проверяется препятствие между центром и точкой цели.
		ray.hit_from_inside = false
		if not hit.point.is_equal_approx(effect.get_spatial().global_position):
			if not space.intersect_ray(ray).is_empty():
				continue

		var weight: float = pow(hit.weight, profile.falloff_power)
		if profile.impulse > 0.0:
			var direction: Vector3 = hit.point - effect.get_spatial().global_position
			if direction.is_zero_approx():
				direction = Vector3.UP
			else:
				direction = direction.normalized()
			direction = (direction + Vector3.UP * profile.upward_bias).normalized()
			_apply_impulse(hit, direction * profile.impulse * weight)

		if EntityAvailability.contains(hit.target, world) and hit.target.has_component(C_Health):
			HazardDamage.submit(
				entity,
				hazard,
				hit.target,
				profile.damage * weight,
				DamageRequest.Type.EXPLOSION,
			)


#endregion

#region Кандидаты и физический импульс
static func _origin_exclusions(origin: Entity) -> Array[RID]:
	var exclusions: Array[RID] = []
	if not is_instance_valid(origin):
		return exclusions

	var root_body: PhysicsBody3D = origin as Node as PhysicsBody3D
	if root_body != null:
		exclusions.append(root_body.get_rid())

	# Однократный обход поддерживает авторские дочерние тела без хранения физических handles.
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


## Временной снимок кандидата одного взрыва, отдельно от сохраняемого ECS-состояния.
class BlastHit extends RefCounted:
	## Физическое тело для импульса и исключения из луча.
	var body: PhysicsBody3D = null
	## Ближайший владелец Health, если collider связан с Entity.
	var target: Entity = null
	## Мировая представительная точка ближайшей формы.
	var point: Vector3 = Vector3.ZERO
	## Линейный вес расстояния до применения falloff_power, в диапазоне 0–1.
	var weight: float = 0.0


static func _apply_impulse(hit: BlastHit, impulse: Vector3) -> void:
	if impulse.is_zero_approx():
		return

	if is_instance_valid(hit.target):
		var motion: C_Motion = hit.target.get_component(C_Motion) as C_Motion
		if motion != null:
			# Управляемый персонаж применяет накопленный импульс в своём физическом callback.
			motion.pending_impulse += impulse
			return

	var rigid: RigidBody3D = hit.body as RigidBody3D
	if rigid == null or rigid.freeze:
		return

	rigid.sleeping = false
	rigid.apply_central_impulse(impulse)

#endregion
