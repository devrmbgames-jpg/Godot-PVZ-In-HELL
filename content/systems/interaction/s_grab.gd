extends System
## Scheduled holder validation/input dispatch. Grab mechanics live in GrabService.
class_name S_Grab


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting] }


func query() -> QueryBuilder:
	return (
		q.with_all([C_Controller, C_Interactor, C_GrabControl, C_CarryLoad])
		.iterate([C_Controller, C_Interactor, C_GrabControl, C_CarryLoad])
	)


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for holder: Entity in entities:
		GrabService.integrate_generic_bodies(holder, delta)
		cmd.add_custom(GrabService.handle_input.bind(holder))
