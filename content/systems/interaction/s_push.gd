extends System
## В расписании GECS проверяет сеанс толкания; связи и физика принадлежат сервисам и solver.
class_name S_Push


## Проверяет Push после наведения и перед командами S_Grab.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting], Runs.Before: [S_Grab] }


## Выбирает акторов с вводом и производным кешем толкания.
func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_PushControl]).iterate([C_PushControl])


## Откладывает проверку действующей пары через CommandBuffer.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for actor: Entity in entities:
		cmd.add_custom(PushService.validate_actor.bind(actor))
