extends DEF_InteractionAction
## Запрашивает проверку выдачи через физическую стойку ПВЗ.
class_name DEF_DeliveryAction


## Проверяет наличие обслуживаемого клиента у стойки.
func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	return source is E_DeliveryCounter and CustomerFlowService.waiting_customer() != null


## Передаёт стойку сервису, который проверяет коробку и результат выдачи.
func execute(_actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerFlowService.confirm_delivery(source as E_DeliveryCounter)
