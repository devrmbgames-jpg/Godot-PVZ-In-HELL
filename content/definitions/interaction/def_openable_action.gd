extends DEF_InteractionAction
## Авторские отдельные Open/Close/Unlock с соответствующими подписями в наборе действий.
class_name DEF_OpenableAction

## Логическая операция открытия, закрытия или разблокировки.
@export var operation: OpenableService.Operation = OpenableService.Operation.OPEN


## Проверяет выбранную операцию для объекта source через OpenableService.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return OpenableService.can_request(actor, source, operation)


## Передаёт логический запрос сервису; физическое положение напрямую не меняет.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	OpenableService.request(actor, source, operation)


## Передаёт запрос и возвращает фактическое принятие операции.
func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	return OpenableService.request(actor, source, operation)
