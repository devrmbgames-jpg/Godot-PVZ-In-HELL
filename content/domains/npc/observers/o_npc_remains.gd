extends Observer
## Добыча возникает из принятого смертельного урона; восстановление C_Death не повторяет событие урона.
class_name O_NpcRemains


## Слушает результаты урона живых существ с профилем останков.
func query() -> QueryBuilder:
	return q.with_all([C_Living, C_NpcRemains]).on_event(DamageResult.EVENT)


## Запрашивает release только для принятого истощения HP данной цели; одноразовый guard принадлежит сервису.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		return
	if result.request == null or result.request.target != entity:
		return

	var remains: C_NpcRemains = entity.get_component(C_NpcRemains) as C_NpcRemains
	cmd.add_custom(_release.bind(weakref(entity), remains))


#region Captured operation
func _release(npc_reference: WeakRef, remains: C_NpcRemains) -> void:
	var npc: Entity = npc_reference.get_ref() as Entity
	if not EntityAvailability.contains(npc, _world) or npc.get_component(C_NpcRemains) != remains:
		return

	NpcRemainsService.release(npc)
#endregion
