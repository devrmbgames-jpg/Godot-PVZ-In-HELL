extends DEF_InteractionAction
## Routes ordinary conversation or a written personal delivery offer through the owning services.
class_name DEF_CustomerAction


#region Contextual request
func caption_for(_actor: Entity, source: Entity, _target: Entity) -> String:
	return tr("Согласиться на доставку") if NpcDialogueService.uses_signboard(source) else caption


func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	if NpcDialogueService.uses_signboard(source):
		return (
			source is E_DistrictNpc
			and InteractionControlFocus.current(actor) < InteractionControlFocus.Priority.PUSH
			and not bool(Console.is_visible())
			and NpcDialogueService.valid_participants(actor, source as E_DistrictNpc)
			and NpcHomeDeliveryService.offer_for(source as E_DistrictNpc) != null
		)
	return CustomerDialogueService.can_start(actor, source as E_NpcCharacter)


func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	if NpcDialogueService.uses_signboard(source):
		NpcHomeDeliveryService.accept(source as E_DistrictNpc)
	else:
		CustomerDialogueService.request_open(actor, source as E_NpcCharacter)


func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	if NpcDialogueService.uses_signboard(source):
		return (
			is_available(actor, source, target)
			and NpcHomeDeliveryService.accept(source as E_DistrictNpc)
		)
	return super.complete(actor, source, target)
#endregion
