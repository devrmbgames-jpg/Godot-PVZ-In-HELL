extends Observer
## Global native UI composition для commerce opening и Night modal cleanup.
class_name O_GameplayPanelRequest


#region Native panel requests
## Принимает domain requests; панели остаются обычными Godot objects.
## Open-handler пишет request.opened после factory; момент доставки задаёт очередь Observer.
func sub_observers() -> Array[Array]:
	return [
		[q.on_event(CommercePanelOpenRequest.EVENT), _open_commerce],
		[q.on_event(BuybackPanelOpenRequest.EVENT), _open_buyback],
		[q.on_event(CraftingPanelOpenRequest.EVENT), _open_crafting],
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


func _open_buyback(_event: Variant, source: Entity, payload: Variant = null) -> void:
	var request: BuybackPanelOpenRequest = payload as BuybackPanelOpenRequest
	assert(request != null)
	var actor: Entity = request.actor_reference.get_ref() as Entity
	var container: E_BuybackContainer = request.container_reference.get_ref() as E_BuybackContainer
	if (
		not EntityAvailability.contains(actor, _world) or actor.id != request.actor_id
		or not EntityAvailability.contains(source, _world)
		or not EntityAvailability.contains(container, _world)
		or container.get_component(C_Buyback) != request.state
		or BuybackQueries.container_for(source) != container
	):
		return
	request.opened = BuybackPanelFactory.open(actor, source) != null


func _open_crafting(_event: Variant, source: Entity, payload: Variant = null) -> void:
	var request: CraftingPanelOpenRequest = payload as CraftingPanelOpenRequest
	assert(request != null)
	var actor: Entity = request.actor_reference.get_ref() as Entity
	var container: E_CraftingContainer = (
		request.container_reference.get_ref() as E_CraftingContainer
	)
	if (
		not EntityAvailability.contains(actor, _world) or actor.id != request.actor_id
		or not EntityAvailability.contains(container, _world) or source != container
		or container.get_component(C_Crafting) != request.state
	):
		return
	request.opened = CraftingPanelFactory.open(actor, container) != null


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
		elif node is CraftingPanel:
			(node as CraftingPanel).close_panel()
		elif node is BuybackPanel:
			(node as BuybackPanel).close_panel()
#endregion
