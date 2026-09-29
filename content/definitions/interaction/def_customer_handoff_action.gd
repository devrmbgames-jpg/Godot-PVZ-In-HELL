extends DEF_InteractionAction
class_name DEF_CustomerHandoffAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return (
		source is E_Customer
		and CustomerFlowService.direct_handoff_package(actor, source as E_Customer) != null
	)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerFlowService.confirm_direct_delivery(actor, source as E_Customer)
