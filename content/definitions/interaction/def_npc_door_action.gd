extends DEF_InteractionAction
## Запрашивает встречу с постоянным получателем у адреса для передачи настоящей коробки.
class_name DEF_NpcDoorAction

#region Встреча у адреса
## Проверяет адрес с принятым заказом и доступность участника; фазу проверяет сервис встречи.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var address: C_NpcAddress = source.get_component(C_NpcAddress) as C_NpcAddress
	return address != null and GrabService.holder_available(actor) and NpcHomeDeliveryService.job_for_address(address.address_id) != null

## Запрашивает появление получателя или продолжает текущую встречу.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	NpcHomeDeliveryService.knock(actor, source)
#endregion
