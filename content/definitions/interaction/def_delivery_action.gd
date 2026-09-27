extends DEF_InteractionAction
class_name DEF_DeliveryAction


func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	return source is E_DeliveryCounter and CustomerFlowService.waiting_customer() != null


func execute(_actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerFlowService.confirm_delivery(source as E_DeliveryCounter)
