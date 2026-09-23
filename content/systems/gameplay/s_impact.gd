extends System
## Owns physical contact snapshots and evaluates both damage directions through S_Damage.
class_name S_Impact

const CONTACT_LIMIT: int = 16
const ENERGY_FACTOR: float = 0.5

var _pairs: Dictionary[String, ImpactContactPair] = { }

var _pending: Dictionary[String, PhysicsContact] = { }


#region GECS



func setup() -> void:
	_world.entity_added.connect(_on_entity_added)
	_world.entity_removed.connect(_on_entity_unavailable)
	_world.entity_disabled.connect(_on_entity_unavailable)
	for entity: Entity in _world.query.execute():
		_on_entity_added(entity)


func query() -> QueryBuilder:
	process_empty = true
	return q


func process(_entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity: Entity in _world.query.with_all([C_ThrowDamage]).execute():
		var context: C_ThrowDamage = entity.get_component(C_ThrowDamage) as C_ThrowDamage
		context.remaining_seconds = maxf(0.0, context.remaining_seconds - delta)
		if context.remaining_seconds <= 0.0:
			context.instigator = null

	for key: String in _pairs.keys():
		var pair: ImpactContactPair = _pairs[key]
		if not is_instance_valid(pair.first) or not is_instance_valid(pair.second):
			_pairs.erase(key)

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
	var owner_impact: S_Impact = null
	for system: System in ECS.world.systems:
		if system is S_Impact and system.active:
			owner_impact = system as S_Impact
			break
	if owner_impact == null:
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
		owner_impact.enqueue(contact)


## Arms only after an actual grip release and nonzero throw impulse.
static func arm_throw(source: Entity, instigator: Entity) -> void:
	var context: C_ThrowDamage = source.get_component(C_ThrowDamage) as C_ThrowDamage
	if context == null:
		return
	context.instigator = instigator
	context.remaining_seconds = maxf(0.0, context.window_seconds)
	context.armed_tick = Engine.get_physics_frames()


## A new grip cancels any old throw attribution immediately.
static func cancel_throw(source: Entity) -> void:
	if not is_instance_valid(source):
		return
	var context: C_ThrowDamage = source.get_component(C_ThrowDamage) as C_ThrowDamage
	if context != null:
		context.remaining_seconds = 0.0
		context.instigator = null


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
	var key: String = _pair_key(contact)
	var pair: ImpactContactPair = _pairs.get(key) as ImpactContactPair
	if pair == null:
		pair = ImpactContactPair.new()
		pair.first = contact.body_a
		pair.second = contact.body_b
		_pairs[key] = pair
	if pair.separated_tick >= 0 and contact.tick > pair.separated_tick:
		pair.resolved = false
		pair.separated_tick = -1
	if pair.resolved:
		return
	pair.resolved = true

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
	var health: C_Health = target.get_component(C_Health) as C_Health
	if health.depleted or health.current <= 0.0:
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
	var context: C_ThrowDamage = (
		source.get_component(C_ThrowDamage) as C_ThrowDamage if source != null else null
	)
	if context != null and context.remaining_seconds > 0.0:
		if contact.tick > context.armed_tick and S_Grab.held_relationship(source) == null:
			request.instigator = context.instigator
			result.amount += maxf(0.0, context.throw_damage)
			cancel_throw(source)
	request.amount = result.amount
	request.damage_type = DamageRequest.Type.IMPACT
	DamageRequestService.submit(request)
	_world.emit_event(ImpactResult.EVENT, target, result)
#endregion


#region Helpers
func _on_entity_added(entity: Entity) -> void:
	var body: RigidBody3D = entity as Node as RigidBody3D
	if body != null:
		var on_exit: Callable = _on_body_exited.bind(body)
		if not body.body_exited.is_connected(on_exit):
			body.body_exited.connect(on_exit)
		body.contact_monitor = true
		body.max_contacts_reported = maxi(body.max_contacts_reported, CONTACT_LIMIT)


func _on_body_exited(other: Node, body: PhysicsBody3D) -> void:
	if not is_instance_valid(other) or not is_instance_valid(body):
		return
	var first_id: int = body.get_instance_id()
	var second_id: int = other.get_instance_id()
	var key: String = "%d:%d" % [mini(first_id, second_id), maxi(first_id, second_id)]
	var pair: ImpactContactPair = _pairs.get(key) as ImpactContactPair
	if pair == null:
		# Preserve separation even when the first impact is still queued.
		pair = ImpactContactPair.new()
		pair.first = body
		pair.second = other as PhysicsBody3D
		_pairs[key] = pair
	pair.separated_tick = Engine.get_physics_frames()


func _on_entity_unavailable(entity: Entity) -> void:
	cancel_throw(entity)
	for key: String in _pairs.keys():
		var pair: ImpactContactPair = _pairs[key]
		if pair.first == entity or pair.second == entity:
			_pairs.erase(key)
	for key: String in _pending.keys():
		var contact: PhysicsContact = _pending[key]
		if contact.body_a == entity or contact.body_b == entity:
			_pending.erase(key)


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
