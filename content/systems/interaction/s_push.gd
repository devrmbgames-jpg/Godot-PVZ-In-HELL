extends System
## Scheduled Push session validation only; ownership/lifecycle/physics live outside the System.
class_name S_Push


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting], Runs.Before: [S_Grab] }


func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_PushControl]).iterate([C_PushControl])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for actor: Entity in entities:
		cmd.add_custom(PushService.validate_actor.bind(actor))
