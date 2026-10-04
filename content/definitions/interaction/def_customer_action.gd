extends DEF_InteractionAction
## Адаптер начала разговора обслуживания с клиентом.
class_name DEF_CustomerAction


## Проверяет доступность начала обслуживания через сервис диалога.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CustomerDialogueService.can_start(actor, source as E_Customer)


## Запрашивает открытие клиентского диалога.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerDialogueService.start(actor, source as E_Customer)
