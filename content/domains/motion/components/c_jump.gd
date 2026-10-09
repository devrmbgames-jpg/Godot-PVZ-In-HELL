extends Component
## Импульс принятого прыжка и история кнопки для защиты повторного удержания.
class_name C_Jump

## Импульс вверх в Н·с, применяемый один раз на принятый прыжок.
@export var jump_force: float = 8.0

## true только в физическом такте принятого прыжка.
@export var active: bool = false

## История кнопки; удержание не запускает прыжок повторно.
var was_pressed: bool = false
