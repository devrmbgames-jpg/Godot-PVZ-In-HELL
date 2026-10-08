extends DEF_InteractionAction
## Запрашивает проверенное размещение Carry в авторскую площадку.
class_name DEF_CarryPlacementAction


## Проверяет размещение Carry в площадку source через общий сервис.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CarryPlacementService.can_place(actor, source as E_PlacementArea)


## Передаёт проверенное размещение сервису, не меняя тело самостоятельно.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CarryPlacementService.place(actor, source as E_PlacementArea)


## Выполняет размещение и возвращает его фактический результат для длительного действия.
func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CarryPlacementService.place(actor, source as E_PlacementArea)
