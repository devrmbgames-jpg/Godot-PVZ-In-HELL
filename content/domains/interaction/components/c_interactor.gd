extends Component
## Параметры луча, текущие цели и подсказка взаимодействия актора.
class_name C_Interactor

## Физические слои, проверяемые лучом взаимодействия.
@export_flags_3d_physics var collision_mask: int = 15
## Максимальная длина взаимодействия, в метрах.
@export_range(0.1, 10.0, 0.1, "or_greater") var interaction_distance: float = 3.0

## Текущая игровая цель взаимодействия; не является связью владения.
var target: Entity = null
## Первое физическое тело под тем же лучом, в том числе вне GECS.
var physics_target: RigidBody3D = null
## Подсказка для чтения интерфейсом, обновляемая на границе игровых команд.
var prompt_text: String = ""
## Номер обработанного снимка ввода, исключающий повторную команду.
var last_action_tick: int = -1
