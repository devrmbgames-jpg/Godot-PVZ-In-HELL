extends RefCounted
## Фактические правила физического удержания; авторский C_Grabbable переопределяет стандартные значения.
class_name GrabControlProfile

## Битовая маска допустимых физических рук; ноль означает только Carry.
var allowed_hand_slots: int = 0
## Ручное вращение доступно для этого хвата.
var manual_rotation_enabled: bool = true
## Допустимые оси ручного смещения относительно точки удержания.
var rotation_axis: C_Grabbable.RotationAxis = C_Grabbable.RotationAxis.FREE
## При подборе принять авторский поворот точки удержания.
var reset_rotation_on_pickup: bool = false
## Сохранять вертикальное положение предмета при удержании.
var keep_upright: bool = false
## Авторская дистанция Carry в метрах; отрицательная использует настройку держателя.
var hold_distance: float = -1.0
## Коэффициент ускорения позиционной пружины.
var position_stiffness: float = 110.0
## Коэффициент демпфирования относительной скорости тела и точки удержания.
var position_damping: float = 22.0
## Предельная сила удержания, в ньютонах.
var max_hold_force: float = 12000.0
## Максимальное отклонение от точки удержания до освобождения, в метрах.
var break_distance: float = 4.0
## Изменение скорости при броске, в метрах в секунду.
var throw_velocity: float = 10.0
## Предельная угловая скорость физического servo, в радианах в секунду.
var max_rotation_speed: float = 30.0


#region Снимок авторских правил
## Копирует авторские настройки в отдельный профиль хвата; null возвращает стандартные значения.
static func from_grabbable(config: C_Grabbable) -> GrabControlProfile:
	var profile: GrabControlProfile = GrabControlProfile.new()
	if config == null:
		return profile

	profile.allowed_hand_slots = config.allowed_hand_slots
	profile.manual_rotation_enabled = config.manual_rotation_enabled
	profile.rotation_axis = config.rotation_axis
	profile.reset_rotation_on_pickup = config.reset_rotation_on_pickup
	profile.hold_distance = config.hold_distance
	profile.position_stiffness = config.position_stiffness
	profile.position_damping = config.position_damping
	profile.max_hold_force = config.max_hold_force
	profile.break_distance = config.break_distance
	profile.throw_velocity = config.throw_velocity
	profile.max_rotation_speed = config.max_rotation_speed
	return profile

#endregion
