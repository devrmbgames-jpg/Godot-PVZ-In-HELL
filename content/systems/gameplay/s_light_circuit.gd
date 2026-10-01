extends System
## Presentation consumes circuit state, including authored/restored disabled circuits.
class_name S_LightCircuit


func query() -> QueryBuilder:
	return q.with_all([C_LightCircuit]).iterate([C_LightCircuit])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var circuits: Array = components[0]
	for index: int in entities.size():
		LightCircuitService.sync(entities[index], circuits[index] as C_LightCircuit)
