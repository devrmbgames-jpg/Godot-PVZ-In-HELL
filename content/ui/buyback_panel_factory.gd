extends RefCounted
## Создаёт native подтверждение скупки через единственный modal focus contract.
class_name BuybackPanelFactory

const PANEL_SCENE: PackedScene = preload("res://content/ui/buyback_panel.tscn")


#region Native panel creation
## Открывает панель без продажи; отказ не оставляет focus или живую панель.
static func open(actor: Entity, trader: Entity) -> BuybackPanel:
	if (
		not GrabQueries.holder_available(actor) or actor.has_component(C_Death)
		or not GrabQueries.holder_available(trader) or trader.has_component(C_Death)
		or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.MODAL
	):
		return null
	var panel: BuybackPanel = PANEL_SCENE.instantiate() as BuybackPanel
	actor.add_child(panel)
	if not panel.open_for(actor, trader):
		panel.queue_free()
		return null
	return panel
#endregion
