extends DEF_InteractionAction
## Street conversation entry action; gameplay consequences belong to the context services.
class_name DEF_NpcDialogueAction

#region Interaction
## Street and waiting-in-queue people can talk when the player explicitly interacts.
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	return NpcDialogueService.can_start(actor, source as E_DistrictNpc)

## Opens one street conversation through its service.
func execute(actor: Entity, source: Entity, _target: Entity) -> void:
	NpcDialogueService.start(actor, source as E_DistrictNpc)
#endregion
