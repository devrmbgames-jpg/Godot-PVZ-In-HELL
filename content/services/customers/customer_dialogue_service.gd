extends RefCounted
## Bounded R12 entry point. DialogueManager resolves text/branches; gameplay services own state.
class_name CustomerDialogueService

const DIALOGUE_PATH: String = "res://content/dialogue/customer_service.dialogue"
const ACTIVE_GROUP: StringName = &"customer_dialogue_panel"


static func start(actor: Entity, customer: E_Customer) -> bool:
	if not is_instance_valid(actor) or not is_instance_valid(customer):
		return false
	var tree: SceneTree = customer.get_tree()
	if tree == null or not tree.get_nodes_in_group(ACTIVE_GROUP).is_empty():
		return false

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return false
	if agent.phase == C_CustomerAgent.Phase.WAITING:
		CustomerFlowService.greet(customer)
		agent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null or agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
		return false

	var resource: DialogueResource = load(DIALOGUE_PATH) as DialogueResource
	if resource == null:
		push_error("R12 dialogue resource is unavailable: %s" % DIALOGUE_PATH)
		return false

	var context: CustomerDialogueContext = CustomerDialogueContext.new(actor, customer)
	if not context.begin():
		return false

	var panel: CustomerDialoguePanel = CustomerDialoguePanel.new()
	var host: Node = tree.current_scene
	if host == null:
		host = tree.root
	host.add_child(panel)
	if not panel.open_for(actor, context, resource, context.dialogue_cue()):
		context.end()
		panel.queue_free()
		return false
	return true
