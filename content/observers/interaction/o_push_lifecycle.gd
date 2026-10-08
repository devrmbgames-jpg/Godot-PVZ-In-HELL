extends Observer
## Применяет и освобождает эффекты толкания по событиям связей и World.
class_name O_PushLifecycle


## Подписывается на удаление и отключение сущностей для освобождения участия.
func setup() -> void:
	_world.entity_removed.connect(PushService.entity_unavailable)
	_world.entity_disabled.connect(PushService.entity_unavailable)


## Подписывается на добавление и удаление R_PushedBy.
func query() -> QueryBuilder:
	return q.on_relationship_added([R_PushedBy]).on_relationship_removed([R_PushedBy])


## Применяет либо освобождает участие; недопустимую связь откладывает к удалению.
func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var relation: Relationship = payload as Relationship
	if relation == null:
		return

	if event == Observer.Event.RELATIONSHIP_ADDED:
		if not PushService.push_added(entity, relation):
			cmd.add_custom(_remove_captured_relationship.bind(weakref(entity), relation))
	elif event == Observer.Event.RELATIONSHIP_REMOVED:
		PushService.push_removed(entity, relation)


#region Captured relationship retirement
func _remove_captured_relationship(owner_reference: WeakRef, captured: Relationship) -> void:
	# GECS pattern removal could otherwise match a replacement after the original binding disappeared.
	var subject: Entity = owner_reference.get_ref() as Entity
	if subject == null or not _world.entity_to_archetype.has(subject) or subject.is_queued_for_deletion():
		return
	if subject.relationships.has(captured):
		subject.remove_relationship(captured)
#endregion
