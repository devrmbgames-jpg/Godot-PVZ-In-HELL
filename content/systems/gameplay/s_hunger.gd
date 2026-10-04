extends System
## Обновляет голод после фаз и до использующих его множитель атак.
class_name S_Hunger


## Читает новую фазу до расчётов боевых множителей.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_DayPhase], Runs.Before: [S_PlayerMelee, S_NpcCombat]}


## Выбирает участников с данными голода.
func query() -> QueryBuilder:
	return q.with_all([C_Hunger]).iterate([C_Hunger])


## Передаёт активное время сервису роста; delta в секундах.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var states: Array = components[0]
	for index: int in entities.size():
		HungerService.tick(entities[index], delta, states[index] as C_Hunger)
