extends System
## Обновляет активные сеансы маркера в расписании GECS и завершает их при выходе системы.
class_name S_Marker


## Обновляет рисование после S_Grab и его снимка управления.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_Grab] }


## Выбирает инструменты с C_Marker.
func query() -> QueryBuilder:
	return q.with_all([C_Marker]).iterate([C_Marker])


## Обновляет только маркеры с активным токеном захвата ввода.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var markers: Array = components[0]
	for index: int in entities.size():
		var marker: C_Marker = markers[index]
		if marker.capture_token != 0:
			MarkerSessionService.update(entities[index], marker)


func _exit_tree() -> void:
	if not is_instance_valid(ECS.world):
		return

	for tool: Entity in ECS.world.query.with_all([C_Marker]).execute():
		MarkerSessionService.end(tool)
