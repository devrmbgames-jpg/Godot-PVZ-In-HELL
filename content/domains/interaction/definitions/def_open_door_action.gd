extends DEF_InteractionAction
## Старая заготовка действия двери; без переопределения недоступна и не выполняет эффекты.
class_name DEF_OpenDoorAction


## Базовая заготовка запрещает действие; переопределение читает состояние из Components.
func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return false


## Пустая базовая реализация; сама по себе дверь не открывает.
func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	pass
