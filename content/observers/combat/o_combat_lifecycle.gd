extends Observer
class_name O_CombatLifecycle


func setup() -> void:
	_world.entity_removed.connect(CombatService.entity_unavailable)
	_world.entity_disabled.connect(CombatService.entity_unavailable)


func query() -> QueryBuilder:
	return q.on_relationship_removed([R_CombatTarget, R_AttackWeapon])


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var relation: Relationship = payload as Relationship
	if relation != null and relation.relation is R_CombatTarget:
		# Incoming links can be removed before World.entity_removed is emitted.
		NpcAttackService.cancel(entity)
		if entity.has_component(C_NpcIntent):
			NpcIntentService.stop(entity)
			NpcIntentService.look_along_movement(entity)
