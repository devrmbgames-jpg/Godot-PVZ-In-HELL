extends DEF_InteractionAction
class_name DEF_CustomerAction


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return CustomerDialogueService.can_start(actor, source as E_Customer)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	CustomerDialogueService.start(actor, source as E_Customer)
