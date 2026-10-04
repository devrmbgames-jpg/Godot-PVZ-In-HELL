extends System
## В расписании GECS исполняет физический адаптер обычных тел и откладывает ввод через GrabService.
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


## Интегрирует обычные тела и откладывает обработку ввода; delta в секундах.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for holder: Entity in entities:
		GrabService.integrate_generic_bodies(holder, delta)
		cmd.add_custom(GrabService.handle_input.bind(holder, delta))
