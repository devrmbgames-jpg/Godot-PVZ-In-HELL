extends GameDefinition
## Авторские локальные положения двери либо выдвижного ящика; движение исполняет физика.
class_name DEF_OpenableMotion

## Локальное положение закрытого физического тела относительно корня объекта.
@export var closed_transform: Transform3D = Transform3D.IDENTITY
## Локальное положение открытого физического тела относительно корня объекта.
@export var open_transform: Transform3D = Transform3D.IDENTITY
## Авторское время полного движения в секундах, ограничивающее скорость мотора.
@export_range(0.01, 60.0, 0.01, "or_greater") var duration_seconds: float = 0.5
## Коэффициент отклика мотора в 1/с; transform тела напрямую не переопределяется.
@export_range(0.1, 60.0) var motor_response: float = 8.0
## Лимит импульса мотора шарнира HingeJoint3D.
@export_range(0.01, 100.0) var hinge_motor_max_impulse: float = 2.0
## Предельная сила линейных моторов, в ньютонах.
@export_range(1.0, 10000.0) var slide_motor_force_limit: float = 120.0
