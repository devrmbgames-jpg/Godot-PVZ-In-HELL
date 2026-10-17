extends RefCounted
## Создаёт одну native панель передачи без расхода до явного подтверждения.
class_name CraftingPanelFactory

const PANEL_SCENE: PackedScene = preload("res://content/ui/crafting_panel.tscn")


#region Native создание
static func open(actor: Entity, container: E_CraftingContainer) -> CraftingPanel:
	if (
		not CraftingQueries.available_reason(container, actor).is_empty()
		or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.MODAL
	):
		return null
	var panel: CraftingPanel = PANEL_SCENE.instantiate() as CraftingPanel
	actor.add_child(panel)
	if not panel.open_for(actor, container):
		panel.queue_free()
		return null
	return panel
#endregion
