extends System
class_name S_PlayerMelee


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_Grab]}


func query() -> QueryBuilder:
	return q.with_all([C_Combat]).iterate([C_Combat])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		cmd.add_custom(CombatService.tick_strike.bind(actor, delta))
