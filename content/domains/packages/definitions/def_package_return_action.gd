extends DEF_InteractionAction
## Запрашивает утренний возврат удерживаемой отказной коробки через взаимодействие с пунктом возврата.
class_name DEF_PackageReturnAction


## Требует доступный пункт возврата source рядом с игроком и допустимую удерживаемую коробку.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return EntityAvailability.contains(source, ECS.world) and GrabReachQueries.within_pickup_reach(actor, source) and PackageReturnService.held_refused(actor) != null


## Повторно проверяет пункт возврата и выполняет возврат через PackageReturnService.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if is_available(actor, source, null):
		PackageReturnService.return_held(actor)
