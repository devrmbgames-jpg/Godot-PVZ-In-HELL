extends Component
## Состояние приседа и авторские высоты головы; столкновения переключает S_Crouch.
class_name C_Crouch


## Принятый присед; встать можно только при свободном пространстве.
@export var active: bool = false

## Высота HeadRoot при стоянии в локальных метрах.
@export var camera_height_standing: float = 1.7
## Высота HeadRoot при приседе в локальных метрах.
@export var camera_height_crouching: float = 1.0

## Скорость изменения высоты HeadRoot в м/с.
@export var transition_speed: float = 8.0

## Доля опускания HeadRoot для поясных креплений; ниже камеры, выше пола.
@export_range(0.0, 1.0, 0.05) var belt_lowering_ratio: float = 0.75
