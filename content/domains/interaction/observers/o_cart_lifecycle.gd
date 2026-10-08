extends Observer
## Применяет и освобождает физические эффекты связей груза и водителя тележки.
class_name O_CartLifecycle


## Подписывается на недоступность тележки, водителя и груза.
func setup() -> void:
	_world.entity_removed.connect(_entity_unavailable)
	_world.entity_disabled.connect(_entity_unavailable)


## Подписывается на добавление и удаление R_CartCargo/R_CartDrivenBy.
func query() -> QueryBuilder:
	return (
		q.on_relationship_added([R_CartCargo, R_CartDrivenBy])
		.on_relationship_removed([R_CartCargo, R_CartDrivenBy])
	)


## Выбирает lifecycle-сервис связи; недопустимую новую связь откладывает к удалению.
func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var binding: Relationship = payload as Relationship
	if binding == null:
		return
	if binding.relation is R_CartCargo:
		if event == Observer.Event.RELATIONSHIP_ADDED:
			if not CartCargoService.cargo_added(entity, binding):
				cmd.add_custom(_remove_captured_relationship.bind(weakref(entity), binding))
		elif event == Observer.Event.RELATIONSHIP_REMOVED:
			CartCargoService.cargo_removed(entity, binding)
	elif binding.relation is R_CartDrivenBy:
		if event == Observer.Event.RELATIONSHIP_ADDED:
			if not CartTransportService.driver_added(entity, binding):
				cmd.add_custom(_remove_captured_relationship.bind(weakref(entity), binding))
		elif event == Observer.Event.RELATIONSHIP_REMOVED:
			CartTransportService.driver_removed(entity, binding)


func _entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return

	CartCargoService.release(entity)
	CartCargoService.release_all(entity)
	CartTransportService.entity_unavailable(entity)


#region Captured relationship retirement
func _remove_captured_relationship(owner_reference: WeakRef, captured: Relationship) -> void:
	# GECS pattern removal could otherwise match a replacement after the original binding disappeared.
	var subject: Entity = owner_reference.get_ref() as Entity
	if subject == null or not _world.entity_to_archetype.has(subject) or subject.is_queued_for_deletion():
		return
	if subject.relationships.has(captured):
		subject.remove_relationship(captured)
#endregion
