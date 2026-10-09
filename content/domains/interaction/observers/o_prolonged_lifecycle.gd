extends Observer
## Освобождает участие немедленно при недоступности сущностей, компонентов или связей.
class_name O_ProlongedLifecycle


## Подписывается на удаление/отключение участников и потерю необходимых компонентов.
func setup() -> void:
	_world.entity_removed.connect(ProlongedInteractionService.entity_unavailable)
	_world.entity_disabled.connect(ProlongedInteractionService.entity_unavailable)
	_world.component_removed.connect(_component_removed)


## Подписывается на удаление R_ProlongedOn и R_ProlongedUsing.
func query() -> QueryBuilder:
	return q.on_relationship_removed([R_ProlongedOn, R_ProlongedUsing])


## Передаёт удалённую связь сервису для очистки участия и обработчиков.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var binding: Relationship = payload as Relationship
	if binding == null:
		return
	if binding.relation is R_ProlongedOn:
		ProlongedInteractionService.removed(entity, binding)
	else:
		ProlongedInteractionService.source_removed(entity, binding)


func _component_removed(entity: Entity, component: Component) -> void:
	if (
		component is C_Controller or component is C_Interactor
		or component is C_GrabControl or component is C_ProlongedInteraction
	):
		ProlongedInteractionService.entity_unavailable(entity)
