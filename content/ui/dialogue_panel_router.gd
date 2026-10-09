extends RefCounted
## Создаёт native панели и контексты по разрешённым domain requests.
class_name DialoguePanelRouter

#region Клиентское представление
## Открывает authored ресурс после реального приветствия и explicit gameplay begin.
static func open_customer(actor: Entity, customer: E_NpcCharacter, captured_agent: C_CustomerAgent) -> bool:
	if not CustomerDialogueService.can_start(actor, customer):
		return false
	if captured_agent.phase == C_CustomerAgent.Phase.WAITING:
		CustomerFlowService.greet(customer)
	if customer.get_component(C_CustomerAgent) != captured_agent or captured_agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return false

	var visit: CustomerVisit = CustomerFlowQueries.find_visit(captured_agent.visit_id)
	var path: String = CustomerDialogueService.DIALOGUE_PATH
	if visit != null and visit.definition != null and not visit.definition.dialogue_resource_path.is_empty():
		path = visit.definition.dialogue_resource_path
	var resource: DialogueResource = load(path) as DialogueResource if ResourceLoader.exists(path) else null
	if resource == null:
		push_error("Customer dialogue resource is unavailable: %s" % path)
		return false
	var context: CustomerDialogueContext = CustomerDialogueContext.new(actor, customer)
	var cue: String = context.dialogue_cue()
	if not resource.cues.has(cue):
		push_warning("Customer dialogue has no '%s' cue: %s" % [cue, path])
		return false
	if not context.begin():
		return false

	var panel: CustomerDialoguePanel = _create_panel(customer.get_tree())
	if not panel.open_for(actor, context, resource, cue):
		panel.close_dialogue()
		context.end()
		panel.queue_free()
		return false

	# Opening can invoke signals/dialogue mutations. Revalidate the captured role before publication.
	if not EntityAvailability.contains(customer, ECS.world) or customer.get_component(C_CustomerAgent) != captured_agent:
		panel.close_dialogue()
		return false
	return CustomerDialogueService.mark_opened(customer, captured_agent)
#endregion

#region Уличное представление
## Открывает существующий уличный ресурс и контекст через explicit NPC begin.
static func open_street(player: Entity, body: E_DistrictNpc) -> bool:
	if not NpcDialogueService.can_start(player, body):
		return false
	var resource: DialogueResource = load(NpcDialogueService.DIALOGUE_PATH) as DialogueResource
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(player, body)
	if resource == null or not resource.cues.has(context.dialogue_cue()) or not context.begin():
		return false

	var panel: CustomerDialoguePanel = _create_panel(body.get_tree())
	if not panel.open_for(player, context, resource, context.dialogue_cue()):
		panel.close_dialogue()
		context.end()
		panel.queue_free()
		return false
	return true


## Закрывает относящиеся к NPC native панели до возвращения синхронного запроса.
static func close_for(body: Entity) -> void:
	for candidate: Variant in (body as Node).get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP):
		# Closing a panel can synchronously release another panel from this captured native group list.
		if not is_instance_valid(candidate):
			continue
		var panel: CustomerDialoguePanel = candidate as CustomerDialoguePanel
		if panel != null and panel.speaks_with(body):
			panel.close_dialogue()
#endregion

#region Хост native панели
static func _create_panel(scene_tree: SceneTree) -> CustomerDialoguePanel:
	var panel: CustomerDialoguePanel = CustomerDialoguePanel.new()
	var host: Node = scene_tree.current_scene
	if host == null:
		host = scene_tree.root
	host.add_child(panel)
	return panel
#endregion
