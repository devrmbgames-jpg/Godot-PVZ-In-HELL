extends Observer
## Global native UI composition для commerce opening и Night modal cleanup.
class_name O_GameplayPanelRequest

#region Native panel requests
## Принимает domain requests; панели остаются обычными Godot objects.
func sub_observers() -> Array[Array]:
	return [
		[q.on_event(CommercePanelOpenRequest.EVENT), _open_commerce],
		[q.on_event(NightUiResetRequest.EVENT), _reset_night_panels],
	]


func _open_commerce(_event: Variant, source: Entity, payload: Variant = null) -> void:
	var request: CommercePanelOpenRequest = payload as CommercePanelOpenRequest
	assert(request != null)
	var actor: Entity = request.actor_reference.get_ref() as Entity
	if not EntityAvailability.contains(actor, _world) or actor.id != request.actor_id:
		return
	if not EntityAvailability.contains(source, _world):
		return
	if source.get_component(C_Trader) != request.trader:
		return
	request.opened = CommercePanelFactory.open(actor, source) != null


func _reset_night_panels(_event: Variant, _source: Entity, payload: Variant = null) -> void:
	var request: NightUiResetRequest = payload as NightUiResetRequest
	assert(request != null)
	var root: Node = request.root_reference.get_ref() as Node
	if root == null:
		return

	for node: Node in root.find_children("*", "", true, false):
		if node is InventoryPanel:
			(node as InventoryPanel).close_inventory()
		elif node is TerminalPanel:
			(node as TerminalPanel).close_panel()
		elif node is CustomerDialoguePanel:
			(node as CustomerDialoguePanel).close_dialogue()
		elif node is CommercePanel:
			(node as CommercePanel).close_panel()
#endregion
