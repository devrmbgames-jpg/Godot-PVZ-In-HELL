extends Observer
## Отменяет действия боя при потере противника, удалении и отключении участника.
class_name O_CombatLifecycle


## Подписывает очистку боя на удаление/отключение сущностей World.
func setup() -> void:
	_world.entity_removed.connect(CombatService.entity_unavailable)
	_world.entity_disabled.connect(CombatService.entity_unavailable)


## Наблюдает снятие живых связей цели и оружия.
func query() -> QueryBuilder:
	return q.on_relationship_removed([R_CombatTarget, R_AttackWeapon])


## При потере цели отменяет атаку и намерение до возможного удаления участника.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var relation: Relationship = payload as Relationship
	if relation != null and relation.relation is R_CombatTarget:
		# Входящие связи могут исчезнуть раньше сигнала World.entity_removed.
		NpcAttackExecutionService.cancel(entity)
		if entity.has_component(C_NpcIntent):
			NpcIntentService.stop(entity)
			NpcIntentService.look_along_movement(entity)
