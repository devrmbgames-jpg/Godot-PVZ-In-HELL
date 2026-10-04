extends NpcDialogueContext
## Контекст уличного разговора для существующего диалогового UI и постоянной личной памяти.
class_name NpcStreetDialogueContext

var _speaker: E_DistrictNpc = null
var _player: Entity = null
var _person_id: StringName = &""

#region Shared presentation
## Hunger changes perceived NPC speech without altering authored text.
func hunger_tier() -> int:
	return HungerService.tier(_player.get_component(C_Hunger) as C_Hunger) if is_instance_valid(_player) else C_Hunger.Tier.NORMAL

## Shared renderer interface, also used by the parcel-service adapter.
func perceived_text(actual_text: String) -> String:
	return "Съешь меня" if hunger_tier() == C_Hunger.Tier.STARVING and not actual_text.is_empty() else actual_text

## Whether this local person can offer a real evening parcel.
func can_offer_delivery() -> bool:
	return _speaker != null and NpcHomeDeliveryService.offer_for(_speaker) != null

## Accepts a voluntary promise through its domain service.
func accept_home_delivery() -> bool:
	return _speaker != null and NpcHomeDeliveryService.accept(_speaker)

## Переносит самостоятельное получение на 1–3 дня после отказа от доставки.
func decline_home_delivery() -> bool:
	return _speaker != null and NpcHomeDeliveryService.decline(_speaker)
#endregion

#region Conversation lifecycle
func _init(actor: Entity, npc: Entity) -> void:
	_speaker = npc as E_DistrictNpc
	_player = actor
	_person_id = NpcSocialService.identity_for(npc)

## Binds the participants only after interaction by the player.
func begin() -> bool:
	if not is_valid() or NpcDialogueService.participant(_speaker) != null:
		return false

	_speaker.add_relationship(Relationship.new(R_NpcConversation.new(), _player))
	NpcIntentService.stop(_speaker)
	return true

## Releases live participants and returns to the interrupted activity.
func end() -> void:
	if is_instance_valid(_speaker):
		NpcDialogueService.end(_speaker)

## Street validity excludes combat, death and walking out of conversation range.
func is_valid() -> bool:
	var person: NpcRecord = DistrictPopulationService.person_for(_person_id)
	var awareness: C_NpcAwareness = _speaker.get_component(C_NpcAwareness) as C_NpcAwareness if is_instance_valid(_speaker) else null
	var player_body: Node3D = _player as Node as Node3D if is_instance_valid(_player) else null
	return person != null and person.death_day == 0 and person.placement == NpcRecord.Placement.STREET and GrabService.holder_available(_player) and GrabService.holder_available(_speaker) and CombatService.target_for(_speaker) == null and (awareness == null or not awareness.fleeing) and player_body != null and _speaker.global_position.distance_to(player_body.global_position) <= DistrictPopulationService.current().definition.conversation_range

## A live relationship must still identify this exact interlocutor.
func can_continue() -> bool:
	return is_valid() and NpcDialogueService.participant(_speaker) == _player

## Selects the intrinsic provocateur branch when appropriate.
func dialogue_cue() -> String:
	var person: NpcRecord = DistrictPopulationService.person_for(_person_id)
	if can_offer_delivery():
		return "delivery_request"
	return "provocation" if person != null and person.profile.rule_for(DEF_NpcTrait.Kind.PROVOCATEUR) != null else "street"

## Readable persistent person name.
func speaker_name() -> String:
	var person: NpcRecord = DistrictPopulationService.person_for(_person_id)
	return person.display_name if person != null else ""

## Interests belong to the person independently of parcel service.
func interests_text() -> String:
	var person: NpcRecord = DistrictPopulationService.person_for(_person_id)
	return ", ".join(person.profile.interests) if person != null else ""

## Uses observed response meaning; repeating a choice in the phase cannot reroll it.
func apply_response_tags(tags: PackedStringArray) -> bool:
	if not is_valid():
		return false

	var kind: CustomerDialogueIntent.Type = CustomerDialogueIntent.from_tags(tags)
	var cycle: C_DayCycle = DayPhaseService.current()
	var incident: StringName = StringName("street/%s/%d/%d/%d" % [_person_id, cycle.day_index, cycle.phase, kind])
	if tags.has("sub"):
		NpcSocialService.react(_speaker, _player, NpcMemory.Kind.SUBMISSION, incident)
	elif kind != CustomerDialogueIntent.Type.NONE:
		NpcSocialService.dialogue_response(_speaker, _player, kind, incident)
	return true
#endregion
