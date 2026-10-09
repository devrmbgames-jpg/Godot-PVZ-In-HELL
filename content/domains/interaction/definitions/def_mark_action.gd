extends DEF_InteractionAction
## Запрашивает рисование маркером через уже выбранную физическую руку.
class_name DEF_MarkAction


## Проверяет инструмент, руку и поверхность через сервис рисования.
func is_available(actor: Entity, source: Entity, target: Entity) -> bool:
	return MarkerSessionService.can_begin(actor, source, target)


## Начинает сеанс рисования; владение вводом остаётся у сервиса.
func execute(actor: Entity, source: Entity, target: Entity) -> void:
	MarkerSessionService.begin(actor, source, target)
