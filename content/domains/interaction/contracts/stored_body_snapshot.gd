extends RefCounted
## Снимок физических настроек для обратимого крепления; не содержит владение Entity.
class_name StoredBodySnapshot

## Исходный признак приостановки симуляции тела.
var freeze: bool = false
## Исходный режим приостановки RigidBody3D.
var freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
## Исходные физические слои предмета.
var collision_layer: int = 0
## Исходная маска проверяемых столкновений предмета.
var collision_mask: int = 0
## Исходное состояние вызова физического процессинга Node.
var physics_processing: bool = false
## Исходное наследование transform от родителя через top_level.
var top_level: bool = false
