@tool
extends DEF_InteractionAction
## Локальная передача материалов у ящика, не требует взгляда/разговора с изготовителем.
class_name DEF_CraftingAction


#region Native действие точки
func is_available(actor: Entity, source: Entity, _target: Entity) -> bool:
	var container: E_CraftingContainer = source as E_CraftingContainer
	return container != null and CraftingQueries.available_reason(container, actor).is_empty()


func execute(actor: Entity, source: Entity, target: Entity) -> void:
	if not is_available(actor, source, target):
		return
	ECS.world.emit_event(
		CraftingPanelOpenRequest.EVENT,
		source,
		CraftingPanelOpenRequest.new(actor, source as E_CraftingContainer),
	)
#endregion
