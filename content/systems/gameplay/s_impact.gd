extends System
## Owns physical contact snapshots and evaluates both damage directions through typed damage events.
class_name S_Impact

const CONTACT_LIMIT: int = 16
const SEPARATION_RETENTION_TICKS: int = 2

var _pairs: Dictionary[String, ImpactContactPair] = { }

var _flush_scheduled: bool = false

var _pending: Dictionary[String, PhysicsContact] = { }


#region GECS

func setup() -> void:
	_world.entity_added.connect(_on_entity_added)
	_world.entity_enabled.connect(_on_entity_added)
	_world.entity_removed.connect(_on_entity_unavailable)
	_world.entity_disabled.connect(_on_entity_unavailable)
	for entity: Entity in _world.query.execute():
		_on_entity_added(entity)


func query() -> QueryBuilder:
	process_empty = true
	return q.enabled().with_all([C_ImpactInbox]).iterate([C_ImpactInbox])


func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	if not components.is_empty():
		var inboxes: Array = components[0]
		for inbox: C_ImpactInbox in inboxes:
			for contact: PhysicsContact in inbox.contacts:
				_enqueue(contact)
			inbox.contacts.clear()
	if not _flush_scheduled:
		_flush_scheduled = true
		cmd.add_custom(_flush_contacts)


func _flush_contacts() -> void:
	_flush_scheduled = false

	for key: String in _pairs.keys():
		var pair: ImpactContactPair = _pairs[key]
		if not is_instance_valid(pair.first) or not is_instance_valid(pair.second):
			_pairs.erase(key)
		elif pair.separated_tick >= 0 and not _pending.has(key):
			if Engine.get_physics_frames() > pair.separated_tick + SEPARATION_RETENTION_TICKS:
				_pairs.erase(key)

	var contacts: Dictionary[String, PhysicsContact] = _pending
	_pending = { }
	for contact: PhysicsContact in contacts.values():
		_resolve(contact)
#endregion


#region Inbox
## Coalesces manifold points and duplicate A/B reports within one physics tick.
func _enqueue(contact: PhysicsContact) -> void:
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
	if _valid(contact):
		_resolve_direction(contact.body_b, contact.body_a, contact)


func _resolve_direction(
	source_body: PhysicsBody3D,
	target_body: PhysicsBody3D,
	contact: PhysicsContact,
) -> void:
	var target: Entity = target_body as Node as Entity
	var source: Entity = source_body as Node as Entity
	if not EntityAvailability.contains(target, _world) or not target.has_component(C_Health):
		return
	var health: C_Health = target.get_component(C_Health) as C_Health
	if health.depleted or health.current <= 0.0:
		return
	if source != null and not EntityAvailability.contains(source, _world):
		return
	# Holding is not a weapon mode; neither participant's holder receives contact damage.
	if _held_pair(source, target) or _held_pair(target, source):
		return
	var receiver: C_ImpactReceiver = target.get_component(C_ImpactReceiver) as C_ImpactReceiver
	if receiver == null:
		return
	var source_rigid: RigidBody3D = source_body as RigidBody3D
	var target_rigid: RigidBody3D = target_body as RigidBody3D
	var source_mass: float = source_rigid.mass if source_rigid != null else 0.0
	if source_rigid == null and target_rigid != null:
		# An immovable environment exchanges the receiver's own moving mass, not infinity.
		source_mass = target_rigid.mass
	var result: ImpactResult = ImpactCalculation.evaluate(
		source_mass,
		contact.normal_speed,
		contact.normal_impulse,
		receiver.profile,
	)
	result.source = source
	result.target = target
	if not result.qualifies:
		return

	var request: DamageRequest = DamageRequest.new()
	request.source = source
	request.target = target
	var context: C_ThrowDamage = (
		source.get_component(C_ThrowDamage) as C_ThrowDamage if source != null else null
	)
	if context != null and context.remaining_seconds > 0.0:
		if contact.tick > context.armed_tick and _held_relationship(source) == null:
			request.instigator = context.instigator
			if is_finite(context.throw_damage):
				result.amount += maxf(0.0, context.throw_damage)
			ThrowContext.cancel(source)
	result.severity = ImpactCalculation.classify(result.amount, receiver.profile)
	if result.amount <= 0.0:
		return

	var protection: C_ImpactProtection = target.get_component(C_ImpactProtection)
	if protection != null and result.severity <= protection.tier:
		result.protected = true
		result.amount = 0.0
		_world.emit_event(ImpactResult.EVENT, target, result)
		return

	# Severity describes the uncapped impact; only HP loss is limited.
	result.amount = ImpactCalculation.cap_damage(
		result.amount,
		health.value,
		receiver.profile,
	)
	if result.amount <= 0.0:
		_world.emit_event(ImpactResult.EVENT, target, result)
		return

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
		if not entity.has_component(C_ImpactInbox):
			entity.add_component(C_ImpactInbox.new())
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
	ThrowContext.cancel(entity)
	var inbox: C_ImpactInbox = entity.get_component(C_ImpactInbox) as C_ImpactInbox
	if inbox != null:
		inbox.contacts.clear()
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
	var grip: Relationship = _held_relationship(candidate)
	return grip != null and grip.target == other
#endregion


static func _held_relationship(entity: Entity) -> Relationship:
	if not is_instance_valid(entity):
		return null
	for grip: Relationship in entity.relationships:
		if grip.relation is R_HeldBy:
			return grip
	return null
