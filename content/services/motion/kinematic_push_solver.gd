extends RefCounted
## Ограниченный импульс при ходьбе; трансформ и скорость предмета остаются у Godot/Jolt.
class_name KinematicPushSolver


static func push_contacts(actor: Entity, body: CharacterBody3D, config: C_CharacterBody, desired: Vector3, delta: float) -> void:
	if desired.is_zero_approx() or delta <= 0.0:
		return

	var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
	var scale: float = maxf(strength.value, 0.0) if strength != null else 1.0
	var visited: Array[RID] = []
	for index: int in body.get_slide_collision_count():
		var collision: KinematicCollision3D = body.get_slide_collision(index)
		var rigid: RigidBody3D = collision.get_collider() as RigidBody3D
		if rigid == null or rigid.freeze or rigid.mass > config.walk_push_maximum_mass * scale or rigid.get_rid() in visited:
			continue

		visited.append(rigid.get_rid())
		var entity: Entity = PhysicsGrabTarget.handle_for(rigid, false)
		if entity != null and (entity.has_component(C_Living) or GrabService.held_relationship(entity) != null or PhysicalSlotService.relationship(entity) != null):
			continue

		var normal: Vector3 = collision.get_normal()
		if absf(normal.y) >= cos(body.floor_max_angle):
			continue

		var direction: Vector3 = Vector3(-normal.x, 0, -normal.z).normalized()
		var target_speed: float = minf(maxf(desired.dot(direction), 0.0), config.walk_push_maximum_speed)
		var current_speed: float = rigid.linear_velocity.dot(direction)
		var impulse: float = minf(config.walk_push_force * scale * delta, maxf(target_speed - current_speed, 0.0) * rigid.mass)
		if impulse > 0.0:
			rigid.apply_central_impulse(direction * impulse)
