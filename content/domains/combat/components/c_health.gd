@tool
extends C_AttributeChanged
## Общие данные здоровья живых участников, посылок и разрушаемых предметов.
class_name C_Health

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["base", "value", "current", "depleted"]

## Унаследованные value и current означают максимум и оставшееся здоровье.
## Обычный расчёт здоровья выполняет O_Damage; истощение терминально до явного восстановления.
@export var depleted: bool = false


#region Определение и доступ к данным
func _init_definition() -> void:
	definition = preload("res://content/domains/combat/definitions/def_attr_health.tres")

# Обёртки доступа к данным здоровья.


## Возвращает вычисленный максимум здоровья.
func get_hp_max() -> float:
	return value


## Возвращает оставшееся здоровье.
func get_hp_current() -> float:
	return current


## Низкоуровневая запись current без проверки и DamageResult; обычный урон проходит через O_Damage.
func set_hp_current(val: float) -> void:
	current = val

#endregion
