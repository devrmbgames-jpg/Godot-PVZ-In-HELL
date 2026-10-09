extends Component
## Настройки управления и снимок опоры; transform/velocity исполняет физическое тело.
class_name C_Motion


#region Авторские настройки

## Максимальная скорость собственного управления в м/с.
##
## Внешний impulse может разогнать его быстрее.
@export var max_speed: float = 6.0

## Ускорение управления на земле в м/с².
@export var ground_acceleration: float = 25.0

## Темп гашения горизонтальной скорости на земле в м/с²
## при отсутствии input.
@export var ground_deceleration: float = 18.0

## Темп гашения бокового скольжения в м/с²,
## когда игрок меняет направление.
@export var ground_lateral_friction: float = 17.0

## Ускорение управления в воздухе в м/с².
##
## Намного слабее ground_acceleration.
@export var air_acceleration: float = 2.0

## Максимальный угол поверхности, считающейся полом, в градусах.
@export_range(0.0, 89.0, 0.1)
var floor_max_angle_degrees: float = 55.0

## Friction поверхности влияет не только на физическое
## торможение, но и на traction самого управления.
@export var surface_friction_affects_control: bool = true

## Минимальная возможность управлять телом даже на льду.
@export_range(0.0, 1.0, 0.01)
var minimum_ground_traction: float = 0.05

## Допуск прилипания к опоре в метрах; 0 отключает коррекцию малых щелей.
@export_range(0.0, 0.5, 0.01) var floor_snap_distance: float = 0.0
## Вертикальное смещение точки ног относительно тела в метрах.
@export var floor_snap_foot_offset: float = 0.0
## Максимальная скорость вверх в м/с для прилипания; более быстрый подъём считается прыжком.
@export var floor_snap_max_upward_speed: float = 2.0



## Полностью отключает locomotion control,
## но не отключает саму физику.
@export var control_enabled: bool = true

#endregion


#region Производное физическое состояние

## S_Sprint владеет усилением; native solver читает его, не меняя max_speed.
var sprint_multiplier: float = 1.0

## Последний физический снимок наличия подходящей опоры.
var is_on_floor: bool = false
## RID физической опоры, отдельно от владения и живых Entity-связей.
var floor_body_rid: RID = RID()
## Мировая точка контакта с опорой в метрах.
var floor_contact_position: Vector3 = Vector3.ZERO

## Мировая нормаль подходящей опоры.
var floor_normal: Vector3 = Vector3.UP

## Мировая скорость опоры в м/с.
var floor_velocity: Vector3 = Vector3.ZERO

## Производный коэффициент трения/управляемости опоры.
var floor_friction: float = 1.0

## Одноразовые мировые игровые импульсы в Н·с:
## explosion, knockback, jump pad и т.д.
var pending_impulse: Vector3 = Vector3.ZERO
## Явный вертикальный игровой импульс блокирует прилипание до снижения.
var floor_snap_blocked: bool = false

#endregion
