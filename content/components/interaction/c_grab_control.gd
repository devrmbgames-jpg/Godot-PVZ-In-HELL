extends Component
## Настройки удержания актора, производные кеши слотов и состояние арбитража управления.
class_name C_GrabControl

## Максимальная дистанция подбора предмета, в метрах.
@export_range(0.1, 10.0, 0.1, "or_greater") var pickup_distance: float = 3.0
## Дистанция обычного Carry перед держателем, в метрах.
@export_range(0.1, 5.0, 0.05, "or_greater") var hold_distance: float = 1.25
## Вращение предмета заняло текущий снимок ввода вместо поворота камеры.
var rotation_active: bool = false
## Производный кеш предмета Carry, обновляемый O_GrabLifecycle и проверяемый по живой связи.
## Для получения владения создаётся R_HeldBy, а не запись в этот кеш.
var held_carry: Entity = null
## Производный кеш предмета правой руки; авторитетность остаётся у R_HeldBy.
var held_right: Entity = null
## Производный кеш предмета левой руки; авторитетность остаётся у R_HeldBy.
var held_left: Entity = null
## Меняет соответствие основного/дополнительного ввода, не перекладывая предметы между руками.
@export var swap_hand_controls: bool = false
## Порог удержания G в секундах для запроса будущего контекстного меню вместо бросания.
@export_range(0.1, 2.0, 0.05) var drop_long_press_seconds: float = 0.45
## Единственный реестр захвата управления; каждый acquire имеет собственный ключ.
var captures: Dictionary[int, InteractionControlCapture] = { }
## Удержание кнопки запросило будущее контекстное меню; текущий короткий сброс подавлен.
var context_wheel_requested: bool = false
