extends System
## Продвигает начатую атаку и при разрешении выбирает следующую через NpcAttackService.
class_name S_NpcCombat


## Исполняет атаки после обслуживания/испытаний и до навигационного намерения.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_ChallengeRuntime], Runs.Before: [S_NpcIntent]}


## Выбирает участников с исполнением атак NPC.
func query() -> QueryBuilder:
	return q.with_all([C_NpcCombat]).iterate([C_NpcCombat])


## Ставит продвижение атаки и разрешённый автоматический выбор в CommandBuffer.
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
