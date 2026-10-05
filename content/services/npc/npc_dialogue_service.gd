extends RefCounted
## Уличный разговор начинается игроком; LimboAI останавливается по живой связи собеседников.
class_name NpcDialogueService

const ACTIVE_GROUP: StringName = &"customer_dialogue_panel"
const DIALOGUE_PATH: String = "res://content/dialogue/npc_street.dialogue"

#region Связи собеседников
## Возвращает авторитетного живого собеседника из Relationships.
static func participant(body: Entity) -> Entity:
	if not is_instance_valid(body):
		return null

	for link: Relationship in body.relationships:
		if link.relation is R_NpcConversation:
			var listener: Entity = link.target as Entity
			return listener if EntityAvailability.contains(listener, ECS.world) and not listener.has_component(C_Death) else null
	return null

## Закрывает разговор после прерывания или обычного закрытия панели.
static func end(body: Entity) -> void:
	if not is_instance_valid(body):
		return

	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcConversation:
			body.remove_relationship(link)

## Закрывает подходящую панель синхронно, освобождая модальный ввод до начала боя.
static func close_for(body: Entity) -> void:
	if not is_instance_valid(body) or not (body as Node).is_inside_tree():
		return
	for node: Node in (body as Node).get_tree().get_nodes_in_group(ACTIVE_GROUP):
		var panel: CustomerDialoguePanel = node as CustomerDialoguePanel
		if panel != null and panel.speaks_with(body):
			panel.close_dialogue()
	end(body)

## Проверяет возможность открытия разговора явным взаимодействием игрока.
static func can_start(player: Entity, body: E_DistrictNpc) -> bool:
	if body == null or InteractionControlFocus.current(player) >= InteractionControlFocus.Priority.PUSH or bool(Console.is_visible()):
		return false

	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(player, body)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	return context.is_valid() and participant(body) == null and (agent == null or agent.phase == C_CustomerAgent.Phase.QUEUED) and body.get_tree().get_nodes_in_group(ACTIVE_GROUP).is_empty()

## Открывает существующий UI с уличным контекстом; UI освобождает захват ввода.
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
