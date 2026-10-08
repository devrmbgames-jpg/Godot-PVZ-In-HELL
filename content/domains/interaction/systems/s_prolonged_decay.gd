extends System
## Обновляет затухание сохранённого прогресса даже без актора, смотрящего на цель.
class_name S_ProlongedDecay


## Выполняет затухание до S_InteractionInput, который обрабатывает активное участие.
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_InteractionInput] }


## Выбирает цели с сохранённым прогрессом длительных действий.
func query() -> QueryBuilder:
	return q.with_all([C_ProlongedInteraction]).iterate([C_ProlongedInteraction])


## Owns idle progression; the pure progress operation contains no target iteration.
func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	for state: C_ProlongedInteraction in components[0]:
		for progress: ProlongedInteractionProgress in state.actions:
			if progress.phase == ProlongedInteractionProgress.Phase.IDLE:
				ProlongedProgressSolver.advance(progress, progress.timing, delta, false)
