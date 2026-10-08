extends Component
## Необязательные авторские настройки удержания, броска и ручного вращения физического предмета.
class_name C_Grabbable

enum HoldSlot {
	CARRY,
	RIGHT_HAND,
	LEFT_HAND,
}
enum RotationAxis {
	FREE,
	Y_ONLY,
}

## Ноль разрешает только Carry; предметы рук задают допустимые физические руки битовой маской.
@export_flags("Right:2", "Left:4") var allowed_hand_slots: int = 0
## Разрешает ручное вращение и соответствующую контекстную подсказку.
@export var manual_rotation_enabled: bool = true
## Ограничивает смещение ручного вращения относительно выбранной точки удержания.
@export var rotation_axis: RotationAxis = RotationAxis.FREE
## При подборе использует авторский поворот точки удержания вместо сохранения относительного поворота.
@export var reset_rotation_on_pickup: bool = false
## Дистанция Carry в метрах; отрицательная берёт C_GrabControl.hold_distance, для рук не применяется.
@export var hold_distance: float = -1.0
## Коэффициент ускорения позиционной пружины; solver отдельно учитывает массу тела.
@export var position_stiffness: float = 110.0
## Коэффициент демпфирования относительного движения тела и точки удержания.
@export var position_damping: float = 22.0
## Предельная угловая скорость удержания в рад/с; столкновения остаются физическими.
@export var max_rotation_speed: float = 30.0
## Предельная сила позиционной пружины, в ньютонах.
@export var max_hold_force: float = 12000.0
## Отклонение от желаемой точки в метрах, при превышении которого хват освобождается.
@export var break_distance: float = 4.0
## Желаемое изменение скорости при броске, в метрах в секунду; тяжёлые профили задают меньше.
@export var throw_velocity: float = 10.0
