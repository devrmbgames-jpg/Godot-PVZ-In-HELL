extends Observer
## Передаёт результат лечения в завершение ожидаемого использования через CommandBuffer.
class_name O_InventoryEffect


## Подписывается на результаты контура урона и лечения.
func query() -> QueryBuilder:
	return q.on_event(DamageResult.EVENT)


## Ставит обработку типизированного результата лечения в CommandBuffer.
func each(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result != null:
		cmd.add_custom(InventoryService.healing_result.bind(result))
