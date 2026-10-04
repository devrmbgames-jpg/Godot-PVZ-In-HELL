extends RefCounted
## Выбранное действие с его источником и текущей целью взаимодействия.
class_name InteractionActionChoice

## Авторское действие, выбранное resolver по доступности и приоритету.
var action: DEF_InteractionAction = null
## Сущность, предоставившая действие: целевой объект либо удерживаемый инструмент.
var source: Entity = null
## Сущность под лучом, передаваемая в проверку и исполнение действия.
var target: Entity = null
