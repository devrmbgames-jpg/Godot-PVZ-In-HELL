extends DEF_InteractionAction
## Адаптер начала разговора обслуживания с клиентом.
class_name DEF_CustomerAction


## Проверяет доступность начала обслуживания через сервис диалога.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CustomerDialogueService.can_start(actor, source as E_NpcCharacter)


## Запрашивает открытие клиентского диалога.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerDialogueService.request_open(actor, source as E_NpcCharacter)
