extends System
## Синхронизирует лампы с состоянием цепи, включая восстановленное выключение.
class_name S_LightCircuit


## Выбирает сущности с данными световой цепи.
func query() -> QueryBuilder:
	return q.with_all([C_LightCircuit]).iterate([C_LightCircuit])


## Применяет enabled и текущую фазу мерцания к авторским группам ламп.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var circuits: Array = components[0]
	for index: int in entities.size():
		LightCircuitService.sync(entities[index], circuits[index] as C_LightCircuit)
