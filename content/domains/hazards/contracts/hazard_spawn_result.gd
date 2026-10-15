extends RefCounted
## Факт регистрации эффекта; профильная настройка и игровой эффект могут выполняться позже.
class_name HazardSpawnResult

const EVENT: StringName = &"hazard_spawned"

## Созданная сущность; получатель отложенного события обязан проверить её доступность.
var hazard: Entity = null
## ID принятого фабрикой запроса.
var request_id: String = ""
## Постоянный ID происхождения созданного эффекта.
var origin_id: String = ""
## Восстановление пересоздаёт геометрию, сохраняя уже разрешённое игровое состояние.
var restored: bool = false
