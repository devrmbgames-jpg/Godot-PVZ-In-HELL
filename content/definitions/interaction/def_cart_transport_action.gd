extends DEF_InteractionAction
## Контекстная команда взять/отпустить ручку транспортной тележки, независимо от Push.
class_name DEF_CartTransportAction

## true освобождает ручку текущей тележки, даже если игрок не смотрит на неё.
@export var release_handle: bool = false


## Для освобождения проверяет текущую тележку, для начала — допустимость ручки.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if release_handle:
		return CartTransportService.current(actor) == source

	return CartTransportService.can_begin(actor, source)


## Повторно проверяет и начинает либо завершает водительское участие.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if not is_available(actor, source, target):
		return

	if release_handle:
		CartTransportService.end(source)
	else:
		CartTransportService.begin(actor, source)
