extends RefCounted
## Мост контактов CharacterBody; S_Impact отправляет урон через общий контракт здоровья.
class_name KinematicImpactCapture

const MINIMUM_MASS: float = 0.01


#region Масса и снимки движения
## Возвращает массу RigidBody/настроенного персонажа в кг; неизвестное тело даёт 0.
static func mass_of(body: PhysicsBody3D) -> float:
	var rigid: RigidBody3D = body as RigidBody3D
	if rigid != null:
		return rigid.mass

	var entity: Entity = body as Node as Entity
	var config: C_CharacterBody = (
		entity.get_component(C_CharacterBody) as C_CharacterBody if entity != null else null
	)
	return config.mass_kg if config != null else 0.0


## После move_and_slide собирает контакты и разделения, исключая предмет держателя; incoming в м/с.
## Импульс оценивается по скорости и приведённой массе; это не measured Jolt contact impulse.
static func capture(
	actor: Entity,
	body: CharacterBody3D,
	config: C_CharacterBody,
	incoming: Vector3,
	incoming_probe: ShapeCast3D = null,
) -> void:
	var collisions: Array[KinematicCollision3D] = []
	for index: int in body.get_slide_collision_count():
		collisions.append(body.get_slide_collision(index))
	if config.bounded_external_motion:
		var probe: KinematicCollision3D = KinematicCollision3D.new()
		if body.test_move(body.global_transform, Vector3.ZERO, probe, body.safe_margin, true, 16):
			collisions.append(probe)
	_capture_collisions(actor, body, config, incoming, collisions, incoming_probe)


## Читает overlap/recovery контакты без движения замороженного тела.
static func capture_stationary(
	actor: Entity,
	body: CharacterBody3D,
	config: C_CharacterBody,
	incoming_probe: ShapeCast3D = null,
) -> void:
	var collisions: Array[KinematicCollision3D] = []
	var probe: KinematicCollision3D = KinematicCollision3D.new()
	if body.test_move(body.global_transform, Vector3.ZERO, probe, body.safe_margin, true, 16):
		collisions.append(probe)
	_capture_collisions(actor, body, config, Vector3.ZERO, collisions, incoming_probe)


static func _capture_collisions(
	actor: Entity,
	body: CharacterBody3D,
	config: C_CharacterBody,
	incoming: Vector3,
	collisions: Array[KinematicCollision3D],
	incoming_probe: ShapeCast3D,
) -> void:
	var inbox: C_ImpactInbox = actor.get_component(C_ImpactInbox) as C_ImpactInbox
	if inbox == null:
		return

	var contacts: Dictionary[int, PhysicsContact] = { }
	var current_bodies: Dictionary[int, WeakRef] = { }
	for collision: KinematicCollision3D in collisions:
		for contact_index: int in collision.get_collision_count():
			var other: PhysicsBody3D = collision.get_collider(contact_index) as PhysicsBody3D
			if other == null:
				continue

			var id: int = other.get_instance_id()
			current_bodies[id] = weakref(other)
			var normal: Vector3 = collision.get_normal(contact_index).normalized()
			config.impulse_velocity = config.impulse_velocity.slide(normal)
			if not config.bounded_external_motion:
				config.impulse_velocity.y = 0.0
			var grip: Relationship = GrabQueries.held_body_relationship(other)
			if grip != null and grip.target == actor:
				continue

			var contact: PhysicsContact = contacts.get(id) as PhysicsContact
			if contact == null:
				contact = PhysicsContact.new()
				contact.body_a = body
				contact.body_b = other
				contact.tick = Engine.get_physics_frames()
				contacts[id] = contact
			var speed: float = maxf(
				0.0,
				(collision.get_collider_velocity(contact_index) - incoming).dot(normal),
			)
			var other_entity: Entity = other as Node as Entity
			var native_reporter: bool = (
				other_entity != null and other_entity.has_component(C_ImpactInbox)
			)
			var previous_motion: C_CharacterBody.BodyMotion = config.incoming_bodies.get(id)
			if (
				not native_reporter and previous_motion != null
				and previous_motion.body.get_ref() == other
				and Engine.get_physics_frames() - previous_motion.tick <= 2
			):
				var contact_offset: Vector3 = (
					collision.get_position(contact_index) - other.global_position
				)
				var point_velocity: Vector3 = (
					previous_motion.linear_velocity
					+ previous_motion.angular_velocity.cross(contact_offset)
				)
				speed = maxf(speed, (point_velocity - incoming).dot(normal))
			var other_mass: float = mass_of(other)
			var transferred_mass: float = config.mass_kg
			if other_mass > 0.0:
				transferred_mass = (
					1.0
					/ (
						1.0 / maxf(config.mass_kg, MINIMUM_MASS)
						+ 1.0 / maxf(other_mass, MINIMUM_MASS)
					)
				)
			if speed >= contact.normal_speed:
				contact.normal_on_a = normal
			contact.normal_speed = maxf(contact.normal_speed, speed)
			contact.normal_impulse = maxf(contact.normal_impulse, speed * transferred_mass)
	for contact: PhysicsContact in contacts.values():
		inbox.contacts.append(contact)
	for id: int in config.contact_bodies:
		if current_bodies.has(id):
			continue

		var previous: PhysicsBody3D = config.contact_bodies[id].get_ref() as PhysicsBody3D
		if previous != null:
			var separation: PhysicsContact = PhysicsContact.new()
			separation.body_a = body
			separation.body_b = previous
			separation.tick = Engine.get_physics_frames()
			inbox.separations.append(separation)
	config.contact_bodies = current_bodies
	_sample_incoming_bodies(config, incoming_probe)


static func _sample_incoming_bodies(config: C_CharacterBody, probe: ShapeCast3D) -> void:
	config.incoming_bodies.clear()
	if probe == null:
		return
	probe.force_shapecast_update()
	for index: int in probe.get_collision_count():
		var body: RigidBody3D = probe.get_collider(index) as RigidBody3D
		if body == null:
			continue
		var reporter: Entity = body as Node as Entity
		if reporter != null and reporter.has_component(C_ImpactInbox):
			continue
		var sample: C_CharacterBody.BodyMotion = C_CharacterBody.BodyMotion.new()
		sample.body = weakref(body)
		sample.linear_velocity = body.linear_velocity
		sample.angular_velocity = body.angular_velocity
		sample.tick = Engine.get_physics_frames()
		config.incoming_bodies[body.get_instance_id()] = sample


## Retires native contact episodes and incoming velocity samples at an explicit lifecycle boundary.
static func reset_contacts(actor: Entity, body: CharacterBody3D, config: C_CharacterBody) -> void:
	var inbox: C_ImpactInbox = actor.get_component(C_ImpactInbox) as C_ImpactInbox
	if inbox != null:
		inbox.contacts.clear()
		for reference: WeakRef in config.contact_bodies.values():
			var previous: PhysicsBody3D = reference.get_ref() as PhysicsBody3D
			if previous != null:
				var separation: PhysicsContact = PhysicsContact.new()
				separation.body_a = body
				separation.body_b = previous
				separation.tick = Engine.get_physics_frames()
				inbox.separations.append(separation)
	config.contact_bodies.clear()
	config.incoming_bodies.clear()

#endregion


#region Отложенный физический отскок
## Оба физических моста используют общую защиту одного разрешения контакта пары.
## Записывает отложенный отскок; скорость меняет только физический callback персонажа.
static func queue_rebound(contact: PhysicsContact) -> void:
	_queue_for(contact.body_a, contact.body_b, contact.normal_on_a, contact)
	_queue_for(contact.body_b, contact.body_a, -contact.normal_on_a, contact)


static func _queue_for(
	body: PhysicsBody3D,
	other: PhysicsBody3D,
	normal: Vector3,
	contact: PhysicsContact,
) -> void:
	var actor: Entity = body as Node as Entity
	if (
		not EntityAvailability.contains(actor, ECS.world)
		or not actor.has_component(C_CharacterBody) or normal.is_zero_approx()
	):
		return

	if actor.has_component(C_Death):
		return
	var config: C_CharacterBody = actor.get_component(C_CharacterBody) as C_CharacterBody
	var grip: Relationship = GrabQueries.held_body_relationship(other)
	if grip != null and (grip.target == actor or config.bounded_external_motion):
		return

	var receiver: C_ImpactReceiver = actor.get_component(C_ImpactReceiver) as C_ImpactReceiver
	if receiver == null or receiver.profile == null:
		return
	if (
		contact.normal_speed < receiver.profile.minimum_speed
		or contact.normal_impulse < receiver.profile.minimum_impulse
	):
		return

	config.pending_rebound_velocity += (
		normal
		* minf(config.maximum_rebound_speed, contact.normal_speed * config.impact_rebound_fraction)
	)

#endregion
