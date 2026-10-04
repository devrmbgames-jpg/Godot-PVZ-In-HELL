extends RefCounted
## Player-initiated street dialogue lifecycle; LimboAI stops for the live participant relationship.
class_name NpcDialogueService

const ACTIVE_GROUP: StringName = &"customer_dialogue_panel"
const DIALOGUE_PATH: String = "res://content/dialogue/npc_street.dialogue"

#region Conversation bindings
## Looks up the authoritative live participant.
static func participant(body: Entity) -> Entity:
	if not is_instance_valid(body):
		return null

	for link: Relationship in body.relationships:
		if link.relation is R_NpcConversation:
			return link.target as Entity if EntityAvailability.contains(link.target, ECS.world) else null
	return null

## Ends a conversation after an interruption or normal panel close.
static func end(body: Entity) -> void:
	if not is_instance_valid(body):
		return

	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcConversation:
			body.remove_relationship(link)

## Returns whether an explicit player interaction can open this conversation.
static func can_start(player: Entity, body: E_DistrictNpc) -> bool:
	if body == null or InteractionControlFocus.current(player) >= InteractionControlFocus.Priority.PUSH or bool(Console.is_visible()):
		return false

	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(player, body)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	return context.is_valid() and participant(body) == null and (agent == null or agent.phase == C_CustomerAgent.Phase.QUEUED) and body.get_tree().get_nodes_in_group(ACTIVE_GROUP).is_empty()

## Opens the existing renderer with the street context; it owns normal input release.
static func start(player: Entity, body: E_DistrictNpc) -> bool:
	if not can_start(player, body):
		return false

	var resource: DialogueResource = load(DIALOGUE_PATH) as DialogueResource
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(player, body)
	if resource == null or not resource.cues.has(context.dialogue_cue()) or not context.begin():
		return false

	var panel: CustomerDialoguePanel = CustomerDialoguePanel.new()
	var host: Node = body.get_tree().current_scene
	if host == null:
		host = body.get_tree().root
	host.add_child(panel)
	if not panel.open_for(player, context, resource, context.dialogue_cue()):
		context.end()
		panel.queue_free()
		return false
	return true
#endregion
