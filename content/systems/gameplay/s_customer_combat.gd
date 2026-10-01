extends System
class_name S_CustomerCombat


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_CustomerChallengeOutcome], Runs.Before: [S_NpcCombat]}


func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent, C_NpcCombat]).iterate([C_CustomerAgent, C_NpcCombat])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		cmd.add_custom(CustomerCombatService.tick.bind(customer as E_Customer))
