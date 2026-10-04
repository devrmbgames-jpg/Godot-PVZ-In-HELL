extends RefCounted
## CharacterBody contact bridge. S_Impact still resolves health through the shared damage contract.
class_name KinematicImpactCapture

const MINIMUM_MASS: float = 0.01


static func mass_of(body: PhysicsBody3D) -> float:
	var rigid: RigidBody3D = body as RigidBody3D
	if rigid != null:
		return rigid.mass

	var entity: Entity = body as Node as Entity
	var config: C_CharacterBody = entity.get_component(C_CharacterBody) as C_CharacterBody if entity != null else null
	return config.mass_kg if config != null else 0.0


static func capture(actor: Entity, body: CharacterBody3D, config: C_CharacterBody, incoming: Vector3) -> void:
	var inbox: C_ImpactInbox = actor.get_component(C_ImpactInbox) as C_ImpactInbox
	if inbox == null:
		return

	var contacts: Dictionary[int, PhysicsContact] = {}
	var current_bodies: Dictionary[int, WeakRef] = {}
	for index: int in body.get_slide_collision_count():
		var collision: KinematicCollision3D = body.get_slide_collision(index)
		var other: PhysicsBody3D = collision.get_collider() as PhysicsBody3D
		if other == null:
			continue

		var id: int = other.get_instance_id()
		current_bodies[id] = weakref(other)
		var normal: Vector3 = collision.get_normal().normalized()
		config.impulse_velocity = config.impulse_velocity.slide(normal)
		config.impulse_velocity.y = 0.0
		var other_entity: Entity = other as Node as Entity
		var grip: Relationship = GrabService.held_relationship(other_entity)
		if grip != null and grip.target == actor:
			continue

		var contact: PhysicsContact = contacts.get(id) as PhysicsContact
		if contact == null:
			contact = PhysicsContact.new()
			contact.body_a = body
			contact.body_b = other
			contact.tick = Engine.get_physics_frames()
			contacts[id] = contact
		var speed: float = maxf(0.0, (collision.get_collider_velocity() - incoming).dot(normal))
		var other_mass: float = mass_of(other)
		var transferred_mass: float = config.mass_kg
		if other_mass > 0.0:
			transferred_mass = 1.0 / (1.0 / maxf(config.mass_kg, MINIMUM_MASS) + 1.0 / maxf(other_mass, MINIMUM_MASS))
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


## Both rigid and kinematic bridges resolve through the same one-contact-per-pair guard.
## Record response data here; only the character physics callback may change its velocity.
static func queue_rebound(contact: PhysicsContact) -> void:
	_queue_for(contact.body_a, contact.body_b, contact.normal_on_a, contact)
	_queue_for(contact.body_b, contact.body_a, -contact.normal_on_a, contact)


static func _queue_for(body: PhysicsBody3D, other: PhysicsBody3D, normal: Vector3, contact: PhysicsContact) -> void:
	var actor: Entity = body as Node as Entity
	if not EntityAvailability.contains(actor, ECS.world) or not actor.has_component(C_CharacterBody) or normal.is_zero_approx():
		return

	var other_entity: Entity = other as Node as Entity
	var grip: Relationship = GrabService.held_relationship(other_entity)
	if grip != null and grip.target == actor:
		return

	var receiver: C_ImpactReceiver = actor.get_component(C_ImpactReceiver) as C_ImpactReceiver
	if receiver == null or receiver.profile == null:
		return
	if contact.normal_speed < receiver.profile.minimum_speed or contact.normal_impulse < receiver.profile.minimum_impulse:
		return

	var config: C_CharacterBody = actor.get_component(C_CharacterBody) as C_CharacterBody
	config.pending_rebound_velocity += normal * minf(config.maximum_rebound_speed, contact.normal_speed * config.impact_rebound_fraction)
