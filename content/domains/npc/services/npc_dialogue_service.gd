extends RefCounted
## Явные границы разговора; R_NpcConversation задаёт собеседника, BT выбирает ветку разговора.
## Native UI и async-реплики принадлежат composition/presentation consumer.
class_name NpcDialogueService

const ACTIVE_GROUP: StringName = &"customer_dialogue_panel"
const DIALOGUE_PATH: String = "res://content/domains/npc/dialogue/npc_street.dialogue"


#region Authored presentation
## Reads the committed personal variant; legacy actors retain their role's fallback.
static func dialogue_path_for(body: Entity, fallback: String = DIALOGUE_PATH) -> String:
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	)
	if person != null and not person.variation.dialogue_path.is_empty():
		return person.variation.dialogue_path
	return fallback


## Reads the trait owner's committed warning; ordinary actors without awareness have none.
static func gaze_warning_given(body: Entity) -> bool:
	if body == null:
		return false
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	return awareness != null and awareness.warned_rules.has(DEF_NpcTrait.Kind.GAZE_AVERSION)


## Reads the authored sign cue from the persistent person; ordinary role actors have no sign mode.
static func uses_signboard(body: Entity) -> bool:
	if body == null:
		return false
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	)
	return person != null and person.profile.presentation_cues.has("npc/angel/sign_dialogue")


## Reads personal resentment from the durable incident owner without changing memory or combat.
static func has_grudge_against(body: Entity, actor: Entity) -> bool:
	if body == null:
		return false
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	)
	return (
		person != null
		and NpcGrudgeRules.remembers_offender(person, NpcSocialService.identity_for(actor))
	)


## Reads demonstrated strength for the recognized actor; dialogue never grants respect.
static func has_respect_for(body: Entity, actor: Entity) -> bool:
	if body == null:
		return false
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	)
	return (
		person != null and NpcPrideRules.selected_rule(person.rules_for()) != null
		and NpcPrideRules.respects(person, NpcSocialService.identity_for(actor))
	)


## Reads durable recognition for this actor; speech cannot create or clear the notice.
static func has_stalking_notice(body: Entity, actor: Entity) -> bool:
	if body == null:
		return false
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = (
		NpcPopulationQueries.person_for(identity.npc_id) if identity != null else null
	)
	return person != null and NpcStalkingRules.noticed(person, NpcSocialService.identity_for(actor))
#endregion


#region Связи собеседников
## Возвращает авторитетного живого собеседника из Relationships.
static func participant(body: Entity) -> Entity:
	if not is_instance_valid(body):
		return null

	for link: Relationship in body.relationships:
		if link.relation is R_NpcConversation:
			var listener: Entity = link.target as Entity
			return (
				listener
				if EntityAvailability.contains(listener, ECS.world)
				and not listener.has_component(C_Death)
				else null
			)
	return null


## Вызывающий предварительно проверяет участников; здесь отвергается только уже связанный разговор.
## True синхронно добавляет R_NpcConversation, stop_movement отдельно отменяет прежнее движение.
static func begin(player: Entity, body: Entity, stop_movement: bool = false) -> bool:
	if participant(body) != null:
		return false

	body.add_relationship(Relationship.new(R_NpcConversation.new(), player))
	if stop_movement:
		NpcIntentService.stop(body)
	return true


## Закрывает разговор после прерывания или обычного закрытия панели.
static func end(body: Entity) -> void:
	if not is_instance_valid(body):
		return

	for link: Relationship in body.relationships.duplicate():
		if link.relation is R_NpcConversation:
			body.remove_relationship(link)


## Запрашивает синхронное закрытие native UI перед дальнейшим gameplay действием.
static func close_for(body: Entity) -> void:
	if not is_instance_valid(body) or not (body as Node).is_inside_tree():
		return
	ECS.world.emit_event(NpcDialogueCloseRequest.EVENT, body, NpcDialogueCloseRequest.new())
	end(body)


## Проверяет живую личность, отсутствие боя/страха и физическую дистанцию разговора.
static func valid_participants(player: Entity, body: E_DistrictNpc) -> bool:
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	if person == null or person.death_day != 0 or person.placement != NpcRecord.Placement.STREET:
		return false
	if (
		not GrabQueries.holder_available(player) or not GrabQueries.holder_available(body)
		or CombatQueries.target_for(body) != null
	):
		return false

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	if awareness != null and awareness.fleeing:
		return false

	var player_body: Node3D = player as Node as Node3D
	return (
		player_body != null
		and body.global_position.distance_to(player_body.global_position)
		<= NpcPopulationQueries.current().definition.conversation_range
	)


## Проверяет optional physical candidate и разрешение его текущей роли без импорта её состояния.
static func can_start(player: Entity, body: E_DistrictNpc) -> bool:
	if (
		body == null or uses_signboard(body)
		or InteractionControlFocus.current(player) >= InteractionControlFocus.Priority.PUSH
		or bool(Console.is_visible())
	):
		return false
	if (
		not valid_participants(player, body) or participant(body) != null
		or not body.get_tree().get_nodes_in_group(ACTIVE_GROUP).is_empty()
	):
		return false
	var permission: NpcConversationPermissionRequest = NpcConversationPermissionRequest.new()
	ECS.world.emit_event(NpcConversationPermissionRequest.EVENT, body, permission)
	return permission.allowed


## Публикует запрос native UI; ресурс и контекст создаёт global composition consumer.
## True подтверждает открытие панели синхронным consumer, не завершение первой async-реплики.
static func request_open(player: Entity, body: E_DistrictNpc) -> bool:
	if not can_start(player, body):
		return false
	var identity: C_NpcIdentity = body.get_component(C_NpcIdentity) as C_NpcIdentity
	var request: NpcDialogueOpenRequest = NpcDialogueOpenRequest.new(player, identity)
	ECS.world.emit_event(NpcDialogueOpenRequest.EVENT, body, request)
	return request.opened
#endregion
