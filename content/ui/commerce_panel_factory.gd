extends RefCounted
## Создаёт одну торговую панель доступного участника с модальным захватом ввода.
class_name CommercePanelFactory


#region Panel construction
## Создаёт панель после проверки участников и приоритета; отказ возвращает null.
static func open(actor: Entity, trader: Entity = null, order_mode: bool = false) -> CommercePanel:
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death) or CommerceService.current() == null or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.MODAL:
		return null
	if trader != null and (not EntityAvailability.contains(trader, ECS.world) or trader.has_component(C_Death)):
		return null

	for child: Node in actor.get_children():
		if child is CommercePanel and not child.is_queued_for_deletion():
			return null

	var panel: CommercePanel = CommercePanel.new()
	actor.add_child(panel)
	if not panel.open_for(actor, trader, order_mode):
		panel.queue_free()
		return null
	return panel
#endregion
