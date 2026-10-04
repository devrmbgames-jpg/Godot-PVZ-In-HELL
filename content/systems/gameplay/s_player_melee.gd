extends System
## Продвигает текущее окно удара игрока через сервис боя и CommandBuffer.
class_name S_PlayerMelee


## Продвигает удар после обработки хвата, чтобы проверить актуальное удержание оружия.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_Grab]}


## Выбирает участника с состоянием удара игрока.
func query() -> QueryBuilder:
	return q.with_all([C_Combat]).iterate([C_Combat])


## Ставит продвижение часов удара в CommandBuffer; delta в секундах.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		cmd.add_custom(CombatService.tick_strike.bind(actor, delta))
