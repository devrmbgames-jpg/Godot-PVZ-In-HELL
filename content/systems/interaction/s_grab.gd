extends System
## В расписании GECS исполняет физический адаптер обычных тел перед S_InteractionInput.
class_name S_Grab


## Исполняется после S_InteractionTargeting и его целей луча.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting] }


## Выбирает держателей с вводом, наведением, контролем хвата и данными Carry.
func query() -> QueryBuilder:
	return (
		q.with_all([C_Controller, C_Interactor, C_GrabControl, C_CarryLoad])
		.iterate([C_Controller, C_Interactor, C_GrabControl, C_CarryLoad])
	)


## Integrates physical proxies; S_InteractionInput owns input arbitration after this stage.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for holder: Entity in entities:
		GrabService.integrate_generic_bodies(holder, delta)
