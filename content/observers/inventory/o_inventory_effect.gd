extends Observer
class_name O_InventoryEffect


func query() -> QueryBuilder:
	return q.on_event(DamageResult.EVENT)


func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result != null:
		cmd.add_custom(InventoryService.healing_result.bind(result))
