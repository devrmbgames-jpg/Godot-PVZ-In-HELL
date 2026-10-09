extends RefCounted
## Explicit Smart Object submission and serialized transactions; Relationships alone own slots.
class_name SmartObjectService

const _ACQUISITION_OPERATIONS: Array[SmartObjectRequest.Operation] = [
	SmartObjectRequest.Operation.ACQUIRE,
	SmartObjectRequest.Operation.USE,
]


#region Public request boundary
## Returns a pending receipt; only the owning Observer can publish committed outcomes.
static func submit(
	operation: SmartObjectRequest.Operation,
	actor: Entity,
	object: Entity,
	affordance_id: StringName,
	token: StringName = &"",
) -> SmartObjectReceipt:
	var receipt: SmartObjectReceipt = SmartObjectReceipt.new()
	var world: World = ECS.world
	if (
		not EntityAvailability.contains(actor, world)
		or not EntityAvailability.contains(object, world)
	):
		_reject(receipt, &"unavailable")
		return receipt
	var incarnation: C_SmartObject = object.get_component(C_SmartObject) as C_SmartObject
	if incarnation == null:
		_reject(receipt, &"missing_smart_object")
		return receipt
	var request: SmartObjectRequest = SmartObjectRequest.new()
	request.operation = operation
	request.actor = weakref(actor)
	request.object = weakref(object)
	request.world = weakref(world)
	request.incarnation = incarnation
	request.affordance_id = affordance_id
	request.token = token
	request.receipt = receipt
	world.emit_event(SmartObjectRequest.EVENT, object, request)
	return receipt


## Read-only input/AI discovery. The commit operation always repeats these checks.
static func is_available(actor: Entity, object: Entity, affordance_id: StringName) -> bool:
	var world: World = ECS.world
	var affordance: DEF_SmartAffordance = _eligible(actor, object, affordance_id, world)
	return affordance != null and not _occupied(object, affordance.slot_id, world)
#endregion


#region Single owning queued operation
## Called exclusively by O_SmartObject after its buffer boundary; never yields.
static func commit(request: SmartObjectRequest, world: World) -> void:
	var receipt: SmartObjectReceipt = request.receipt
	if receipt.status != SmartObjectReceipt.Status.PENDING:
		return
	var actor: Entity = request.actor.get_ref() as Entity
	var object: Entity = request.object.get_ref() as Entity
	if request.world.get_ref() != world or ECS.world != world:
		_reject(receipt, &"world_replaced")
		return
	if (
		not EntityAvailability.contains(actor, world)
		or not EntityAvailability.contains(object, world)
	):
		_reject(receipt, &"unavailable")
		return
	if object.get_component(C_SmartObject) != request.incarnation:
		_reject(receipt, &"incarnation_replaced")
		return
	if request.operation not in [
		SmartObjectRequest.Operation.ACQUIRE,
		SmartObjectRequest.Operation.USE,
		SmartObjectRequest.Operation.EXECUTE,
		SmartObjectRequest.Operation.CANCEL,
	]:
		_reject(receipt, &"invalid_operation")
		return

	var binding: Relationship = null
	if request.operation in _ACQUISITION_OPERATIONS:
		var affordance: DEF_SmartAffordance = _eligible(actor, object, request.affordance_id, world)
		if affordance == null:
			_reject(receipt, &"ineligible")
			return
		if _occupied(object, affordance.slot_id, world):
			_reject(receipt, &"occupied")
			return
		# No yield/callback lies between the final occupancy check and relation publication.
		request.incarnation.acquisition_sequence += 1
		var reservation: R_SmartObjectReservation = R_SmartObjectReservation.new()
		reservation.affordance_id = request.affordance_id
		reservation.slot_id = affordance.slot_id
		reservation.token = StringName(
			"smart:%d:%d:%d:%d"
			% [
				world.get_instance_id(),
				object.get_instance_id(),
				request.incarnation.get_instance_id(),
				request.incarnation.acquisition_sequence,
			]
		)
		binding = Relationship.new(reservation, object)
		reservation.retirement_callback = _participant_exiting.bind(weakref(actor), binding)
		actor.tree_exiting.connect(reservation.retirement_callback)
		object.tree_exiting.connect(reservation.retirement_callback)
		actor.add_relationship(binding)
		if not actor.relationships.has(binding):
			_reject(receipt, &"acquisition_cancelled")
			return
		receipt.token = reservation.token
		if request.operation == SmartObjectRequest.Operation.ACQUIRE:
			receipt.status = SmartObjectReceipt.Status.ACQUIRED
			receipt.reason = &"acquired"
			return
	else:
		binding = _binding_for(actor, object, request.affordance_id, request.token)
		if binding == null:
			_reject(receipt, &"stale_token")
			return
		receipt.token = request.token

	var reservation: R_SmartObjectReservation = binding.relation as R_SmartObjectReservation
	if reservation.executing:
		_reject(receipt, &"executing")
		return
	var occupants: Array[Relationship] = _slot_bindings(object, reservation.slot_id, world)
	if occupants.size() != 1 or occupants[0] != binding:
		_retire(actor, binding)
		_reject(receipt, &"slot_conflict")
		return
	if request.operation == SmartObjectRequest.Operation.CANCEL:
		_retire(actor, binding)
		receipt.status = SmartObjectReceipt.Status.CANCELLED
		receipt.reason = &"cancelled"
		return
	var affordance: DEF_SmartAffordance = _eligible(actor, object, request.affordance_id, world)
	if affordance == null or affordance.slot_id != reservation.slot_id:
		_retire(actor, binding)
		_reject(receipt, &"ineligible")
		return
	reservation.executing = true
	var succeeded: bool = affordance.executor.complete(actor, object, object)
	reservation.executing = false
	# The executor can synchronously trigger lifecycle cleanup; never remove its replacement.
	var surviving_actor: Entity = request.actor.get_ref() as Entity
	if surviving_actor != null:
		_retire(surviving_actor, binding)
	receipt.status = (
		SmartObjectReceipt.Status.SUCCEEDED
		if succeeded
		else SmartObjectReceipt \
				.Status \
				.REJECTED
	)
	receipt.reason = &"executed" if succeeded else &"executor_rejected"
#endregion


#region Derived occupancy and exact retirement
## Accepted snapshot reconstruction ends transient participation without saving tokens.
static func retire_world(world: World) -> void:
	for actor: Entity in world.entities.duplicate():
		for binding: Relationship in actor.relationships.duplicate():
			if binding.relation is R_SmartObjectReservation:
				_retire(actor, binding)


## Discrete death/removal/disable/component-loss reaction, including outgoing participation.
static func entity_unavailable(entity: Entity, world: World) -> void:
	for actor: Entity in world.entities.duplicate():
		for binding: Relationship in actor.relationships.duplicate():
			if (
				binding.relation is R_SmartObjectReservation
				and (actor == entity or binding.target == entity)
			):
				_retire(actor, binding)


static func _retire(actor: Entity, binding: Relationship) -> void:
	if actor.relationships.has(binding):
		actor.remove_relationship(binding)
	detach_retirement(actor, binding)


## Removes derived engine hooks after native removal, even when World removed the relation first.
static func detach_retirement(actor: Entity, binding: Relationship) -> void:
	var reservation: R_SmartObjectReservation = binding.relation as R_SmartObjectReservation
	var callback: Callable = reservation.retirement_callback
	if not callback.is_valid():
		return
	if actor.tree_exiting.is_connected(callback):
		actor.tree_exiting.disconnect(callback)
	# The stored target is revalidated at this actual asynchronous retirement boundary.
	if is_instance_valid(binding.target):
		var object: Entity = binding.target as Entity
		if object.tree_exiting.is_connected(callback):
			object.tree_exiting.disconnect(callback)
	reservation.retirement_callback = Callable()


static func _participant_exiting(actor_reference: WeakRef, binding: Relationship) -> void:
	var actor: Entity = actor_reference.get_ref() as Entity
	if actor != null:
		_retire(actor, binding)


static func _binding_for(
	actor: Entity,
	object: Entity,
	affordance_id: StringName,
	token: StringName,
) -> Relationship:
	if token.is_empty():
		return null
	for binding: Relationship in actor.relationships:
		if binding.target != object or not binding.relation is R_SmartObjectReservation:
			continue
		var reservation: R_SmartObjectReservation = binding.relation as R_SmartObjectReservation
		if reservation.affordance_id == affordance_id and reservation.token == token:
			return binding
	return null


static func _occupied(object: Entity, slot_id: StringName, world: World) -> bool:
	return not _slot_bindings(object, slot_id, world).is_empty()


static func _slot_bindings(
	object: Entity,
	slot_id: StringName,
	world: World,
) -> Array[Relationship]:
	var bindings: Array[Relationship] = []
	for actor: Entity in world.entities:
		for binding: Relationship in actor.relationships:
			if binding.target == object and binding.relation is R_SmartObjectReservation:
				if (binding.relation as R_SmartObjectReservation).slot_id == slot_id:
					bindings.append(binding)
	return bindings


static func _eligible(
	actor: Entity,
	object: Entity,
	affordance_id: StringName,
	world: World,
) -> DEF_SmartAffordance:
	if (
		not EntityAvailability.contains(actor, world)
		or not EntityAvailability.contains(object, world)
	):
		return null
	if actor.has_component(C_Death) or object.has_component(C_Death):
		return null
	var object_data: C_SmartObject = object.get_component(C_SmartObject) as C_SmartObject
	if object_data == null or object_data.definition == null:
		return null
	var affordance: DEF_SmartAffordance = object_data.definition.affordance_for(affordance_id)
	if affordance == null or affordance.executor == null:
		return null
	var service_slot: DEF_SmartSlot = object_data.definition.slot_for(affordance.slot_id)
	if service_slot == null or not object.get_node_or_null(service_slot.marker) is Marker3D:
		return null
	for capability: Script in affordance.required_actor_components:
		if capability == null or not actor.has_component(capability):
			return null
	if not affordance.executor.is_available(actor, object, object):
		return null
	return affordance


static func _reject(receipt: SmartObjectReceipt, reason: StringName) -> void:
	receipt.reason = reason
	receipt.status = SmartObjectReceipt.Status.REJECTED
#endregion
