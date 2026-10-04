extends System
## Планирует движение и столкновение снарядов через сервис после атак NPC.
class_name S_CombatProjectile


## Движется после возможного запуска снаряда атакой NPC.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcCombat]}


## Выбирает данные живых снарядов.
func query() -> QueryBuilder:
	return q.with_all([C_CombatProjectile]).iterate([C_CombatProjectile])


## Ставит физическую проверку шага полёта в CommandBuffer; delta в секундах.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for projectile: Entity in entities:
		cmd.add_custom(ProjectileService.tick.bind(projectile, delta))
