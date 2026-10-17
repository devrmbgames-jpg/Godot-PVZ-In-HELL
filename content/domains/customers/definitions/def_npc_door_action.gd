extends DEF_InteractionAction
## Запрашивает встречу с постоянным получателем у адреса для передачи настоящей коробки.
class_name DEF_NpcDoorAction


#region Встреча у адреса
## Недоступность получателя видна у двери без раскрытия скрытой причины и даты возврата.
func caption_for(_actor: Entity, source: Entity, _target: Entity) -> String:
	var address: C_NpcAddress = source.get_component(C_NpcAddress) as C_NpcAddress
	var job: NpcHomeDelivery = (
		HomeMeetingQueries.job_for_address(address.address_id) if address != null else null
	)
	if job != null:
		var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
		if person != null and person.death_day > 0:
			return "Получатель временно недоступен"
	return caption


## Проверяет адрес с принятым заказом и доступность участника; фазу проверяет сервис встречи.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var address: C_NpcAddress = source.get_component(C_NpcAddress) as C_NpcAddress
	return (
		address != null and GrabQueries.holder_available(actor)
		and HomeMeetingQueries.job_for_address(address.address_id) != null
	)


## Запрашивает появление получателя или продолжает текущую встречу.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	NpcHomeDeliveryService.knock(actor, source)
#endregion
