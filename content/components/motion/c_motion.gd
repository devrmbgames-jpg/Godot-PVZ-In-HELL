extends Component
class_name C_Motion


#region Configuration

## Максимальная скорость, которую персонаж способен набрать
## собственным управлением.
##
## Внешний impulse может разогнать его быстрее.
@export var max_speed: float = 6.0

## Ускорение управления на земле.
@export var ground_acceleration: float = 25.0

## Насколько быстро гасится горизонтальная скорость на земле
## при отсутствии input.
@export var ground_deceleration: float = 18.0

## Насколько быстро убирается боковое скольжение,
## когда игрок меняет направление.
@export var ground_lateral_friction: float = 17.0

## Управление в воздухе.
##
## Намного слабее ground_acceleration.
@export var air_acceleration: float = 2.0

## Максимальный угол поверхности, считающейся полом.
@export_range(0.0, 89.0, 0.1)
var floor_max_angle_degrees: float = 55.0

## Friction поверхности влияет не только на физическое
## торможение, но и на traction самого управления.
@export var surface_friction_affects_control: bool = true

## Минимальная возможность управлять телом даже на льду.
@export_range(0.0, 1.0, 0.01)
var minimum_ground_traction: float = 0.05

## Optional support adhesion for small floor seams. Zero disables it (NPC default).
@export_range(0.0, 0.5, 0.01) var floor_snap_distance: float = 0.0
@export var floor_snap_foot_offset: float = 0.0
## Faster upward motion is a launch/jump and must not be snapped to support.
@export var floor_snap_max_upward_speed: float = 2.0



## Полностью отключает locomotion control,
## но не отключает саму физику.
@export var control_enabled: bool = true

#endregion


#region Runtime

## S_Sprint владеет усилением; native solver читает его, не меняя max_speed.
var sprint_multiplier: float = 1.0

var is_on_floor: bool = false
## Derived physics support snapshot; RID is not an Entity ownership/binding.
var floor_body_rid: RID = RID()
var floor_contact_position: Vector3 = Vector3.ZERO

var floor_normal: Vector3 = Vector3.UP

var floor_velocity: Vector3 = Vector3.ZERO

var floor_friction: float = 1.0

## Одноразовые игровые импульсы:
## explosion, knockback, jump pad и т.д.
var pending_impulse: Vector3 = Vector3.ZERO
## Explicit upward gameplay impulses suspend adhesion until descent.
var floor_snap_blocked: bool = false

#endregion
