extends System
## Обновляет игровые и физические цели первого попадания луча без представления.
class_name S_InteractionTargeting


## Выбирает акторов с C_Interactor для обновления целей луча.
func query() -> QueryBuilder:
	return q.with_all([C_Interactor]).iterate([C_Interactor])


## Для доступного актора обновляет обе цели; для недоступного очищает их.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var interactors: Array = components[0]
	for index: int in entities.size():
		var holder: Entity = entities[index]
		var interactor: C_Interactor = interactors[index]
		if not GrabService.holder_available(holder):
			interactor.target = null
			interactor.physics_target = null
			continue

		interactor.target = InteractionTargetingGeometry.find_target(holder, interactor)
		interactor.physics_target = InteractionTargetingGeometry.find_physics_target(holder, interactor)
