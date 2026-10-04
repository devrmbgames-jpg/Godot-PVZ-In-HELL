extends System
## Накапливает покой по авторским правилам; сама фиксация исполняется отдельной командой.
class_name S_AnchorStability


## Выбирает включённые сущности с C_Anchorable.
func query() -> QueryBuilder:
	return q.enabled().with_all([C_Anchorable]).iterate([C_Anchorable])


## Обновляет накопленный покой каждой цели через сервис; delta в секундах.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var anchorables: Array = components[0]
	for entity_index: int in entities.size():
		var config: C_Anchorable = anchorables[entity_index] as C_Anchorable
		AnchoringService.update_stability(entities[entity_index], config, delta)
