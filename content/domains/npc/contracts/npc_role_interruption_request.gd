extends RefCounted
## Синхронная граница прерывания необязательной роли NPC; базовый AI не знает её владельца.
class_name NpcRoleInterruptionRequest

## Канал запроса до продолжения обычного NPC lifecycle.
const EVENT: StringName = &"npc_role_interruption_request"
## Причина, выбранная владельцем AI или маршрута.
enum Kind { FLEE_EXIT, ROUTE_BLOCKED, EMERGENCY }
## Зафиксированная причина запроса.
var kind: Kind = Kind.EMERGENCY
## Потребитель активной роли отмечает обработку; отсутствие роли допускает обычный schedule cleanup.
var handled: bool = false

#region Создание запроса
## Создаёт запрос одного синхронного прерывания без сохранения тела или роли.
func _init(interruption_kind: Kind = Kind.EMERGENCY) -> void:
	kind = interruption_kind
#endregion
