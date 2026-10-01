extends System
class_name S_CombatProjectile


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_NpcCombat]}


func query() -> QueryBuilder:
	return q.with_all([C_CombatProjectile]).iterate([C_CombatProjectile])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for projectile: Entity in entities:
		cmd.add_custom(ProjectileService.tick.bind(projectile, delta))
