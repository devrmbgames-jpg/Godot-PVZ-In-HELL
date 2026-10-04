extends System
class_name S_NpcCombat


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_CustomerChallengeOutcome], Runs.Before: [S_NpcIntent]}


func query() -> QueryBuilder:
	return q.with_all([C_NpcCombat]).iterate([C_NpcCombat])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		cmd.add_custom(_step.bind(actor, delta))


func _step(actor: Entity, delta: float) -> void:
	if CombatService.target_for(actor) == null:
		return

	NpcAttackService.tick(actor, delta)
	var state: C_NpcCombat = actor.get_component(C_NpcCombat) as C_NpcCombat
	if state != null and state.automatic_attack_selection:
		NpcAttackService.choose_and_start(actor)
