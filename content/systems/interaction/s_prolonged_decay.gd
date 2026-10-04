extends System
## Обновляет затухание сохранённого прогресса даже без актора, смотрящего на цель.
class_name S_ProlongedDecay


## Выполняет затухание до S_Grab, который обрабатывает активное участие.
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_Grab] }


## Выбирает цели с сохранённым прогрессом длительных действий.
func query() -> QueryBuilder:
	return q.with_all([C_ProlongedInteraction]).iterate([C_ProlongedInteraction])


## Продвигает простой по авторским правилам через сервис; delta в секундах.
func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	for state: C_ProlongedInteraction in components[0]:
		ProlongedInteractionService.decay(state, delta)
