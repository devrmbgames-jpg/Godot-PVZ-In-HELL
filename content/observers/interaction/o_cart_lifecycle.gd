extends Observer
## Applies/reverses Cart cargo and driver Relationship lifecycle side effects.
class_name O_CartLifecycle


func setup() -> void:
	_world.entity_removed.connect(_entity_unavailable)
	_world.entity_disabled.connect(_entity_unavailable)


func query() -> QueryBuilder:
	return (
		q.on_relationship_added([R_CartCargo, R_CartDrivenBy])
		.on_relationship_removed([R_CartCargo, R_CartDrivenBy])
	)


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var binding: Relationship = payload as Relationship
	if binding == null:
		return
	if binding.relation is R_CartCargo:
		if event == Observer.Event.RELATIONSHIP_ADDED:
			if not S_CartCargo.cargo_added(entity, binding):
				cmd.add_custom(entity.remove_relationship.bind(binding))
		elif event == Observer.Event.RELATIONSHIP_REMOVED:
			S_CartCargo.cargo_removed(entity, binding)
	elif binding.relation is R_CartDrivenBy:
		if event == Observer.Event.RELATIONSHIP_ADDED:
			if not S_CartTransport.driver_added(entity, binding):
				cmd.add_custom(entity.remove_relationship.bind(binding))
		elif event == Observer.Event.RELATIONSHIP_REMOVED:
			S_CartTransport.driver_removed(entity, binding)


func _entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	S_CartCargo.release(entity)
	S_CartCargo.release_all(entity)
	S_CartTransport.entity_unavailable(entity)
