extends Observer
## Сопровождает живые связи хранения и носителя, освобождая крепления при недоступности.
class_name O_PhysicalSlotLifecycle


## Подписывается на недоступность участников и компонентов физических слотов.
func setup() -> void:
	_world.entity_removed.connect(PhysicalSlotService.entity_removed)
	_world.entity_disabled.connect(PhysicalSlotService.entity_unavailable)
	_world.component_removed.connect(_component_removed)


## Подписывается на R_StoredIn и удаление R_SlotMountedOn.
func query() -> QueryBuilder:
	return q.on_relationship_added([R_StoredIn]).on_relationship_removed([R_StoredIn, R_SlotMountedOn])


## Применяет либо очищает крепление; недопустимую связь откладывает к удалению.
func each(event: Variant, entity: Entity, payload: Variant = null) -> void:
	var binding: Relationship = payload as Relationship
	if binding == null:
		return
	if binding.relation is R_SlotMountedOn:
		PhysicalSlotService.entity_unavailable(entity)
		return
	if event == Observer.Event.RELATIONSHIP_ADDED:
		if not PhysicalSlotService.attach(entity, binding):
			cmd.add_custom(entity.remove_relationship.bind(binding))
	else:
		PhysicalSlotService.detach(entity, binding)


func _component_removed(entity: Entity, component: Component) -> void:
	if component is C_PhysicalSlot or component is C_Grabbable:
		PhysicalSlotService.entity_unavailable(entity)
