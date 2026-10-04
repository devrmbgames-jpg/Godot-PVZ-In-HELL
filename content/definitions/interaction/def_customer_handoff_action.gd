extends DEF_InteractionAction
## Запрашивает непосредственную выдачу удерживаемой коробки клиенту.
class_name DEF_CustomerHandoffAction


## Проверяет настоящую подходящую коробку в руках и получателя.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return (
		source is E_Customer
		and CustomerFlowService.direct_handoff_package(actor, source as E_Customer) != null
	)


## Повторно проверяет и фиксирует выдачу через сервис обслуживания.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerFlowService.confirm_direct_delivery(actor, source as E_Customer)
