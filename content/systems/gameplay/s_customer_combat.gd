extends System
## Планирует прежнюю клиентскую эскалацию перед общим исполнением атак NPC.
class_name S_CustomerCombat


## Обрабатывает прежнюю эскалацию после обслуживания и до атак NPC.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_CustomerChallengeOutcome], Runs.Before: [S_NpcCombat]}


## Выбирает обслуживаемых клиентов с боевыми возможностями.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerAgent, C_NpcCombat]).iterate([C_CustomerAgent, C_NpcCombat])


## Ставит адаптер клиентского боя в CommandBuffer; постоянный NPC пропускается сервисом.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for customer: Entity in entities:
		cmd.add_custom(CustomerCombatService.tick.bind(customer as E_Customer))
