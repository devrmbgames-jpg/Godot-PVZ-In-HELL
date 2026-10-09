extends RefCounted
## Обратимый снимок всех настроек RigidBody3D, изменяемых фиксацией игрока.
class_name AnchoredBodySnapshot

## Исходное разрешение симуляции тела через freeze.
var freeze: bool = false
## Исходный режим заморозки RigidBody3D.
var freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
## Исходное разрешение сна тела.
var can_sleep: bool = true
## Исходное фактическое состояние сна.
var sleeping: bool = false
## Исходная мировая линейная скорость, в метрах в секунду.
var linear_velocity: Vector3 = Vector3.ZERO
## Исходная угловая скорость, в радианах в секунду.
var angular_velocity: Vector3 = Vector3.ZERO
