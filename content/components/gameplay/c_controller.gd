extends Component
class_name C_Controller

## Semantic input for the current physics tick; only the input producer writes these.
var interact_pressed: bool = false
var action_main_pressed: bool = false
var action_second_held: bool = false
var look_delta: Vector2 = Vector2.ZERO

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
