extends Component
class_name C_Look

@export var look_direction: Vector3 = Vector3.FORWARD
## Скорость поворота, градусов в секунду.
## Для игрока можно поставить 9999.
@export var look_acceleration: float = 360.0

## На сколько градусов голова может повернуться относительно тела,
## прежде чем начнет разворачиваться само тело.
@export_range(0.0, 180.0, 1.0)
var head_yaw_limit: float = 60.0


## Скорость разворота тела в сторону движения, градусов в секунду.
@export var motion_alignment_acceleration: float = 180.0
