extends Component
## Намерения текущего физического такта; игровые потребители не переписывают поля ввода.
class_name C_Controller

## Событие основного взаимодействия текущего физического такта; пишет производитель ввода.
var interact_pressed: bool = false
## Удержание основного взаимодействия текущего такта.
var interact_held: bool = false
## Удержание действия предмета выбранной руки.
var use_held: bool = false
## Новый запрос бега текущего такта.
var sprint_pressed: bool = false
## Удержание бега текущего такта.
var sprint_held: bool = false
## Ввод бега разрешён текущим контекстом.
var sprint_input_enabled: bool = false
## Запрос отмены рисования без переключения общего режима курсора.
var cancel_pressed: bool = false
## Новый запрос действия удерживаемого предмета.
var use_pressed: bool = false
## Новый запрос дополнительного действия.
var action_second_pressed: bool = false
## Модификатор физического действия вместо обычного использования предмета.
var physical_override: bool = false
## Номер актуального снимка ввода для защиты однократного действия.
var input_tick: int = 0
## Новый запрос основного действия.
var action_main_pressed: bool = false
## Удержание дополнительного действия.
var action_second_held: bool = false
## Изменение взгляда, накопленное производителем ввода для текущего такта.
var look_delta: Vector2 = Vector2.ZERO
## Исходные плоские оси ввода: X вбок, отрицательный Y вперёд; пишет S_PlayerInput.
var move_axis: Vector2 = Vector2.ZERO
## Удержание управления вращением предмета.
var rotate_held: bool = false
## Короткий запрос отпускания/броска.
var drop_pressed: bool = false
## Однократный запрос долгого отпускания.
var drop_long_pressed: bool = false
## Производитель ввода отсчитывает удержание кнопки отпускания.
var drop_tracking: bool = false
## Прошедшее удержание кнопки отпускания в секундах.
var drop_elapsed: float = 0.0
## Долгое действие уже сообщено и не повторяется до отпускания.
var drop_long_fired: bool = false

## Намерение куда смотреть
@export var direction_look: Vector3 = Vector3.FORWARD

## Намерение куда идти
@export var direction_motion: Vector3 = Vector3.ZERO
## Навигационное уклонение задаёт предел скорости вместе с направлением.
## false сохраняет обычную инерцию и внешние импульсы движения игрока.
var limit_motion_velocity: bool = false

## Намерение вызвать какое то взаимодействие (E)
@export var interract_main: bool = false

## Намерение вызвать какое то дополнительное взаимодействие (F)
@export var interract_second: bool = false

## Основное действие (ЛКМ)
@export var action_main: bool = false

## Дополнительное действие (ПКМ)
@export var action_second: bool = false

## Действие прыжка (SPACE)
@export var action_jump: bool = false


## Действие Присесть (С)
@export var action_crouch: bool = false
