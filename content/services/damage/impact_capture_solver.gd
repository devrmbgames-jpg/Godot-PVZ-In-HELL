extends RefCounted
## Снимает контакты Godot в данные тела без расчёта урона и поиска Systems.
class_name ImpactCaptureSolver


## Вызывается первым при интеграции тела, до вспомогательных сил хвата/движения.
static func capture(entity: Entity, state: PhysicsDirectBodyState3D) -> void:
	if not EntityAvailability.contains(entity, ECS.world):
		return

	var inbox: C_ImpactInbox = entity.get_component(C_ImpactInbox) as C_ImpactInbox
	if inbox == null:
		return

	inbox.contacts.clear()
	var manifolds: Dictionary[int, PhysicsContact] = { }
	for index: int in state.get_contact_count():
		var other: PhysicsBody3D = state.get_contact_collider_object(index) as PhysicsBody3D
		if not is_instance_valid(other):
			continue

		var other_id: int = other.get_instance_id()
		var contact: PhysicsContact = manifolds.get(other_id) as PhysicsContact
		if contact == null:
			contact = PhysicsContact.new()
			contact.body_a = entity as Node as PhysicsBody3D
			contact.body_b = other
			contact.tick = Engine.get_physics_frames()
			manifolds[other_id] = contact

		# Jolt сообщает нормаль и скорости точек контакта в мировых осях.
		var normal: Vector3 = state.get_contact_local_normal(index).normalized()
		var relative: Vector3 = (
			state.get_contact_collider_velocity_at_position(index)
			- state.get_contact_local_velocity_at_position(index)
		)
		var normal_speed: float = maxf(0.0, relative.dot(normal))
		if normal_speed >= contact.normal_speed:
			contact.normal_on_a = normal
		contact.normal_speed = maxf(contact.normal_speed, normal_speed)
		contact.normal_impulse += absf(state.get_contact_impulse(index).dot(normal))
	for contact: PhysicsContact in manifolds.values():
		inbox.contacts.append(contact)
