extends System
class_name S_Hunger


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_DayPhase], Runs.Before: [S_PlayerMelee, S_NpcCombat]}


func query() -> QueryBuilder:
	return q.with_all([C_Hunger]).iterate([C_Hunger])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var states: Array = components[0]
	for index: int in entities.size():
		HungerService.tick(entities[index], delta, states[index] as C_Hunger)
