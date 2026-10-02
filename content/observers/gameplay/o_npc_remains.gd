extends Observer
## Actual lethal damage creates loot; loading a saved C_Death never replays damage.
class_name O_NpcRemains


func query() -> QueryBuilder:
	return q.with_all([C_Living, C_NpcRemains]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.outcome != DamageResult.Outcome.HEALTH_DEPLETED:
		return
	if result.request == null or result.request.target != entity:
		return
	cmd.add_custom(NpcRemainsService.release.bind(entity))
