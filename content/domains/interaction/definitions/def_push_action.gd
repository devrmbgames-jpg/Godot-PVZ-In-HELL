extends DEF_InteractionAction
## Контекстная команда начала/окончания толкания тележки, без занятия слота Grab.
class_name DEF_PushAction

## true завершает участие в текущей тележке без требования наведения на неё.
@export var end_push: bool = false


## Для завершения проверяет текущую тележку, для начала — полную допустимость участия.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if end_push:
		return PushService.pushed_object(actor) == source

	return PushService.can_begin(actor, source)


## Повторно проверяет и начинает либо завершает Push через сервис.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if not is_available(actor, source, target):
		return

	if end_push:
		PushService.end(actor, source)
	else:
		PushService.try_begin(actor, source)
