extends Observer
## Применяет и очищает физические эффекты R_HeldBy; принадлежность определяет сама связь.
class_name O_GrabLifecycle


## Подписывается на удаление и отключение сущностей для освобождения хвата.
func setup() -> void:
	_world.entity_removed.connect(GrabService.entity_unavailable)
	_world.entity_disabled.connect(GrabService.entity_unavailable)


## Подписывается на добавление и удаление R_HeldBy.
func query() -> QueryBuilder:
	return q.on_relationship_added([R_HeldBy]).on_relationship_removed([R_HeldBy])


## Применяет эффекты живой связи; недопустимую связь откладывает к удалению через CommandBuffer.
func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var grip: Relationship = payload as Relationship
	if grip == null:
		return
	if event == Observer.Event.RELATIONSHIP_ADDED:
		if not GrabService.grip_added(entity, grip):
			cmd.add_custom(_remove_captured_relationship.bind(weakref(entity), grip))
	elif event == Observer.Event.RELATIONSHIP_REMOVED:
		GrabService.grip_removed(entity, grip)


#region Captured relationship retirement
func _remove_captured_relationship(owner_reference: WeakRef, captured: Relationship) -> void:
	# GECS pattern removal could otherwise match a replacement after the original binding disappeared.
	var subject: Entity = owner_reference.get_ref() as Entity
	if subject == null or not _world.entity_to_archetype.has(subject) or subject.is_queued_for_deletion():
		return
	if subject.relationships.has(captured):
		subject.remove_relationship(captured)
#endregion
