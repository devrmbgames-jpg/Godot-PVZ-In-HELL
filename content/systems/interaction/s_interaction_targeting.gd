extends System
## Writes authoritative first-hit gameplay/physics targets only.
class_name S_InteractionTargeting


func query() -> QueryBuilder:
	return q.with_all([C_Interactor]).iterate([C_Interactor])


func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var interactors: Array = components[0]
	for index: int in entities.size():
		var holder: Entity = entities[index]
		var interactor: C_Interactor = interactors[index]
		if not GrabService.holder_available(holder):
			interactor.target = null
			interactor.physics_target = null
			continue
		interactor.target = InteractionTargetingService.find_target(holder, interactor)
		interactor.physics_target = InteractionTargetingService.find_physics_target(holder, interactor)
