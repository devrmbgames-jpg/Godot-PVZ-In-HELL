extends Component
## Per-physics-tick actor intent; gameplay consumers never rewrite input fields.
class_name C_Controller

## Semantic input for the current physics tick; only the input producer writes these.
var interact_pressed: bool = false
var use_pressed: bool = false
var action_second_pressed: bool = false
var physical_override: bool = false
var input_tick: int = 0
var action_main_pressed: bool = false
var action_second_held: bool = false
var look_delta: Vector2 = Vector2.ZERO
## Raw planar input intent: X steering, negative Y forward; written only by S_PlayerInput.
var move_axis: Vector2 = Vector2.ZERO
var rotate_held: bool = false
var drop_pressed: bool = false
var drop_long_pressed: bool = false
var drop_tracking: bool = false
var drop_elapsed: float = 0.0
var drop_long_fired: bool = false

## Намерение куда смотреть
@export var direction_look: Vector3 = Vector3.FORWARD

## Намерение куда идти
@export var direction_motion: Vector3 = Vector3.ZERO

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
