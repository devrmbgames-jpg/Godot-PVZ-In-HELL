extends Observer
## Applies and reverses Push side effects for relationship and world lifecycle events.
class_name O_PushLifecycle


func setup() -> void:
	_world.entity_removed.connect(PushService.entity_unavailable)
	_world.entity_disabled.connect(PushService.entity_unavailable)


func query() -> QueryBuilder:
	return q.on_relationship_added([R_PushedBy]).on_relationship_removed([R_PushedBy])


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var relation: Relationship = payload as Relationship
	if relation == null:
		return

	if event == Observer.Event.RELATIONSHIP_ADDED:
		if not PushService.push_added(entity, relation):
			cmd.add_custom(entity.remove_relationship.bind(relation))
	elif event == Observer.Event.RELATIONSHIP_REMOVED:
		PushService.push_removed(entity, relation)
