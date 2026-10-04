extends System
## Планирует ограниченную районную порцию восприятия и решений LimboAI до боя/навигации.
class_name S_NpcDecision

#region Планирование сервисного шага
## Решения следуют за районом/обслуживанием и предшествуют бою/навигации.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_District, S_CustomerFlow], Runs.Before: [S_NpcCombat, S_NpcIntent] }

## Выбирает районные сессии для общего обновления NPC.
func query() -> QueryBuilder:
	return q.with_all([C_District]).iterate([C_District])

## Ставит ограниченный шаг NpcBrainService в CommandBuffer; delta в секундах.
func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var districts: Array = components[0]
	for district: C_District in districts:
		cmd.add_custom(NpcBrainService.tick.bind(district, delta))
#endregion
