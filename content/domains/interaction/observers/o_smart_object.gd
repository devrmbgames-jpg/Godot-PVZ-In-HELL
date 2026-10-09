extends Observer
## Owns queued Smart Object transactions and discrete loss/death retirement; no scheduled tick.
class_name O_SmartObject

# These references observe pending receipts in cmd; the buffer alone schedules operations.
var _pending_requests: Array[SmartObjectRequest] = []


#region Commit and lifecycle boundaries
func setup() -> void:
	_world.entity_removed.connect(_entity_unavailable)
	_world.entity_disabled.connect(_entity_unavailable)
	_world.component_added.connect(_component_added)
	_world.component_removed.connect(_component_removed)


func query() -> QueryBuilder:
	return q \
			.on_event(SmartObjectRequest.EVENT) \
			.on_event(WorldReconstructionStarted.EVENT) \
			.on_relationship_removed([R_SmartObjectReservation])


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var binding: Relationship = payload as Relationship
	if binding != null and binding.relation is R_SmartObjectReservation:
		SmartObjectService.detach_retirement(entity, binding)
		return
	if payload is WorldReconstructionStarted:
		_reject_pending(&"world_reconstructed")
		SmartObjectService.retire_world(_world)
		return
	var request: SmartObjectRequest = payload as SmartObjectRequest
	if request != null and request.object.get_ref() == entity:
		_pending_requests.append(request)
		cmd.add_custom(_commit.bind(request))


func _commit(request: SmartObjectRequest) -> void:
	_pending_requests.erase(request)
	SmartObjectService.commit(request, _world)


func _reject_pending(reason: StringName) -> void:
	for request: SmartObjectRequest in _pending_requests:
		request.receipt.reason = reason
		request.receipt.status = SmartObjectReceipt.Status.REJECTED
	_pending_requests.clear()
	if cmd != null:
		cmd.clear()


func _exit_tree() -> void:
	_reject_pending(&"owner_removed")


func _entity_unavailable(entity: Entity) -> void:
	SmartObjectService.entity_unavailable(entity, _world)


func _component_added(entity: Entity, component: Component) -> void:
	if component is C_Death:
		_entity_unavailable(entity)


func _component_removed(entity: Entity, component: Component) -> void:
	if component is C_SmartObject:
		_entity_unavailable(entity)
		return
	for binding: Relationship in entity.relationships.duplicate():
		if not binding.relation is R_SmartObjectReservation:
			continue
		var object: Entity = binding.target as Entity
		var data: C_SmartObject = object.get_component(C_SmartObject) as C_SmartObject
		var reservation: R_SmartObjectReservation = binding.relation as R_SmartObjectReservation
		var affordance: DEF_SmartAffordance = data.definition.affordance_for(
			reservation.affordance_id
		)
		for required_component: Script in affordance.required_actor_components:
			if not entity.has_component(required_component):
				entity.remove_relationship(binding)
				break
#endregion
