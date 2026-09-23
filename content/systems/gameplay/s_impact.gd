extends System
## Owns physical contact snapshots and evaluates both damage directions through S_Damage.
class_name S_Impact

const CONTACT_LIMIT: int = 16
const ENERGY_FACTOR: float = 0.5

var _pending: Dictionary[String, PhysicsContact] = { }


#region GECS
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_Damage] }


func setup() -> void:
	_world.entity_added.connect(_on_entity_added)
	for entity: Entity in _world.query.execute():
		_on_entity_added(entity)


func query() -> QueryBuilder:
	process_empty = true
	return q


func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	var contacts: Dictionary[String, PhysicsContact] = _pending
	_pending = { }
	for contact: PhysicsContact in contacts.values():
		cmd.add_custom(_resolve.bind(contact))
#endregion


#region Physics bridge
## Called first in body integration, before holding/motion assistance changes velocities.
static func capture(entity: Entity, state: PhysicsDirectBodyState3D) -> void:
	if not S_Grab.entity_available(entity):
		return
	var owner: S_Impact = null
	for system: System in ECS.world.systems:
		if system is S_Impact and system.active:
			owner = system as S_Impact
			break
	if owner == null:
		return

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

		# Jolt stores the body-side contact normal/point velocities in world axes.
		var normal: Vector3 = state.get_contact_local_normal(index).normalized()
		var relative: Vector3 = (
			state.get_contact_collider_velocity_at_position(index)
			- state.get_contact_local_velocity_at_position(index)
		)
		contact.normal_speed = maxf(contact.normal_speed, relative.dot(normal))
		contact.normal_impulse += absf(state.get_contact_impulse(index).dot(normal))
	for contact: PhysicsContact in manifolds.values():
		owner.enqueue(contact)


## Coalesces manifold points and duplicate A/B reports within one physics tick.
func enqueue(contact: PhysicsContact) -> void:
	if not _valid(contact):
		return
	var key: String = _pair_key(contact)
	var existing: PhysicsContact = _pending.get(key) as PhysicsContact
	if existing == null:
		_pending[key] = contact
	else:
		existing.normal_speed = maxf(existing.normal_speed, contact.normal_speed)
		existing.normal_impulse = maxf(existing.normal_impulse, contact.normal_impulse)
#endregion


#region Resolution
## Generic directional formula; both speed and real impulse must cross receiver thresholds.
static func evaluate(
	source_mass: float,
	normal_speed: float,
	normal_impulse: float,
	receiver: C_ImpactReceiver,
) -> ImpactResult:
	var result: ImpactResult = ImpactResult.new()
	if receiver == null or not is_finite(source_mass) or source_mass <= 0.0:
		return result
	if not is_finite(normal_speed) or not is_finite(normal_impulse):
		return result
	if normal_speed < receiver.minimum_speed or normal_impulse < receiver.minimum_impulse:
		return result

	var kinetic_energy: float = ENERGY_FACTOR * source_mass * normal_speed * normal_speed
	var contact_work: float = ENERGY_FACTOR * normal_impulse * normal_speed
	result.transferred_energy = minf(kinetic_energy, contact_work)
	result.amount = maxf(0.0, result.transferred_energy - receiver.absorption_joules)
	result.amount *= maxf(0.0, receiver.damage_per_joule)
	if result.amount > 0.0:
		result.severity = ImpactResult.Severity.Weak
	if result.amount >= receiver.medium_damage:
		result.severity = ImpactResult.Severity.Medium
	if result.amount >= receiver.strong_damage:
		result.severity = ImpactResult.Severity.Strong
	return result


func _resolve(contact: PhysicsContact) -> void:
	if not _valid(contact):
		return
	_resolve_direction(contact.body_a, contact.body_b, contact)
	_resolve_direction(contact.body_b, contact.body_a, contact)


func _resolve_direction(
	source_body: PhysicsBody3D,
	target_body: PhysicsBody3D,
	contact: PhysicsContact,
) -> void:
	var target: Entity = target_body as Node as Entity
	var source: Entity = source_body as Node as Entity
	if not S_Grab.entity_available(target) or not target.has_component(C_Health):
		return
	if source != null and not S_Grab.entity_available(source):
		return
	# Holding is not a weapon mode; neither participant's holder receives contact damage.
	if _held_pair(source, target) or _held_pair(target, source):
		return
	var receiver: C_ImpactReceiver = target.get_component(C_ImpactReceiver) as C_ImpactReceiver
	var source_rigid: RigidBody3D = source_body as RigidBody3D
	var target_rigid: RigidBody3D = target_body as RigidBody3D
	var source_mass: float = source_rigid.mass if source_rigid != null else 0.0
	if source_rigid == null and target_rigid != null:
		# An immovable environment exchanges the receiver's own moving mass, not infinity.
		source_mass = target_rigid.mass
	var result: ImpactResult = evaluate(
		source_mass,
		contact.normal_speed,
		contact.normal_impulse,
		receiver,
	)
	result.source = source
	result.target = target
	if result.amount <= 0.0:
		return

	var request: DamageRequest = DamageRequest.new()
	request.source = source
	request.target = target
	request.amount = result.amount
	request.damage_type = DamageRequest.Type.IMPACT
	S_Damage.submit(request)
	_world.emit_event(ImpactResult.EVENT, target, result)
#endregion


#region Helpers
func _on_entity_added(entity: Entity) -> void:
	var body: RigidBody3D = entity as Node as RigidBody3D
	if body != null:
		body.contact_monitor = true
		body.max_contacts_reported = maxi(body.max_contacts_reported, CONTACT_LIMIT)


static func _valid(contact: PhysicsContact) -> bool:
	return (
		contact != null and is_instance_valid(contact.body_a)
		and is_instance_valid(contact.body_b) and contact.body_a != contact.body_b
	)


static func _pair_key(contact: PhysicsContact) -> String:
	var first: int = contact.body_a.get_instance_id()
	var second: int = contact.body_b.get_instance_id()
	return "%d:%d" % [mini(first, second), maxi(first, second)]


static func _held_pair(candidate: Entity, other: Entity) -> bool:
	if not is_instance_valid(candidate):
		return false
	var grip: Relationship = S_Grab.held_relationship(candidate)
	return grip != null and grip.target == other
#endregion
