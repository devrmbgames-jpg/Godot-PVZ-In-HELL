extends Observer
class_name O_GrabLifecycle


func setup() -> void:
	_world.entity_removed.connect(S_Grab.entity_unavailable)
	_world.entity_disabled.connect(S_Grab.entity_unavailable)


func query() -> QueryBuilder:
	return q.on_relationship_added([R_HeldBy]).on_relationship_removed([R_HeldBy])


func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var grip: Relationship = payload as Relationship
	if grip == null:
		return
	if event == Observer.Event.RELATIONSHIP_ADDED:
		if not S_Grab.grip_added(entity, grip):
			cmd.add_custom(entity.remove_relationship.bind(grip))
	elif event == Observer.Event.RELATIONSHIP_REMOVED:
		S_Grab.grip_removed(entity, grip)
