extends DEF_InteractionAction
## Generic player adapter; AI/quests/dialogue use the same typed service without this adapter.
class_name DEF_SmartObjectAction

## Authored operation selected through the source's materialized C_SmartObject.
@export var affordance_id: StringName = &""


#region Input adapter
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return SmartObjectService.is_available(actor, source, affordance_id)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	SmartObjectService.submit(SmartObjectRequest.Operation.USE, actor, source, affordance_id)


## A pending queued operation is never reported as completed; callers use its receipt.
func complete(actor: Entity, source: Entity, _target: Entity) -> bool:
	var receipt: SmartObjectReceipt = SmartObjectService.submit(
		SmartObjectRequest.Operation.USE,
		actor,
		source,
		affordance_id,
	)
	return receipt.status == SmartObjectReceipt.Status.SUCCEEDED
#endregion
