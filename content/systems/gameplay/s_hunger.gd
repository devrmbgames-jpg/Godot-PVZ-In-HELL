extends System
class_name S_Hunger


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_DayPhase], Runs.Before: [S_PlayerMelee, S_NpcCombat]}


func query() -> QueryBuilder:
	return q.with_all([C_Hunger]).iterate([C_Hunger])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		HungerService.tick(actor, delta)
