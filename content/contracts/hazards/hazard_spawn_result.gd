extends RefCounted
## Типизированный результат фабрики для независимых обработчиков и проверок.
class_name HazardSpawnResult

const EVENT: StringName = &"hazard_spawned"

## Созданная сущность опасного эффекта.
var hazard: Entity = null
## ID принятого фабрикой запроса.
var request_id: String = ""
## Постоянный ID происхождения созданного эффекта.
var origin_id: String = ""
## Восстановление пересоздаёт геометрию, сохраняя уже разрешённое игровое состояние.
var restored: bool = false
