extends System
## Accumulates authored rest time; fix itself remains a discrete command transaction.
class_name S_AnchorStability


func query() -> QueryBuilder:
	return q.enabled().with_all([C_Anchorable]).iterate([C_Anchorable])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var anchorables: Array = components[0]
	for entity_index: int in entities.size():
		var config: C_Anchorable = anchorables[entity_index] as C_Anchorable
		AnchoringService.update_stability(entities[entity_index], config, delta)
