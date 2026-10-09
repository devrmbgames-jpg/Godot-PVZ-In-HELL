extends NpcDialogueContext
## Контекст уличного разговора для существующего диалогового UI и постоянной личной памяти.
class_name NpcStreetDialogueContext

var _speaker: E_DistrictNpc = null
var _player: Entity = null
var _person_id: StringName = &""

#region Общее отображение
## Голод меняет воспринимаемую речь NPC без изменения авторского текста.
func hunger_tier() -> int:
	return HungerRules.tier(_player.get_component(C_Hunger) as C_Hunger) if is_instance_valid(_player) else C_Hunger.Tier.NORMAL

## Общий интерфейс отображения для уличного и клиентского контекстов.
func perceived_text(actual_text: String) -> String:
	var hunger: C_Hunger = _player.get_component(C_Hunger) as C_Hunger if is_instance_valid(_player) else null
	return "Съешь меня" if HungerRules.sees_npcs_as_food(hunger) and not actual_text.is_empty() else actual_text

## Проверяет, может ли местный житель предложить настоящую вечернюю посылку.
func can_offer_delivery() -> bool:
	return _speaker != null and NpcHomeDeliveryService.offer_for(_speaker) != null

## Принимает добровольное обещание через сервис доставки.
func accept_home_delivery() -> bool:
	return is_valid() and NpcHomeDeliveryService.accept(_speaker)

## Переносит самостоятельное получение на 1–3 дня после отказа от доставки.
func decline_home_delivery() -> bool:
	return is_valid() and NpcHomeDeliveryService.decline(_speaker)

## Позволяет закрыть именно этот уличный разговор перед боем.
func speaks_with(npc: Entity) -> bool:
	return _speaker == npc

func _delivery_offer() -> NpcHomeDelivery:
	var visit: CustomerVisit = NpcHomeDeliveryService.offer_for(_speaker) if _speaker != null else null
	return HomeDeliveryQueries.personal_for(visit.customer_id, visit.visit_id) if visit != null else null

func _delivery_npc() -> E_DistrictNpc:
	return _speaker

func _delivery_player() -> Entity:
	return _player
#endregion

#region Жизненный цикл разговора
func _init(actor: Entity, npc: Entity) -> void:
	_speaker = npc as E_DistrictNpc
	_player = actor
	_person_id = NpcSocialService.identity_for(npc)

## Связывает собеседников только после взаимодействия игрока.
func begin() -> bool:
	if not is_valid() or NpcDialogueService.participant(_speaker) != null:
		return false

	return NpcDialogueService.begin(_player, _speaker, true)

## Освобождает живых собеседников и возвращает NPC к прерванному занятию.
func end() -> void:
	if _closed:
		return
	_closed = true
	if is_instance_valid(_speaker):
		NpcDialogueService.end(_speaker)

## Уличный разговор недоступен при бое, смерти или превышении дистанции.
func is_valid() -> bool:
	if _closed or not EntityAvailability.contains(_speaker, ECS.world) or not EntityAvailability.contains(_player, ECS.world):
		return false
	return NpcDialogueService.valid_participants(_player, _speaker)

## Живая связь должна по-прежнему указывать на этого собеседника.
func can_continue() -> bool:
	return is_valid() and NpcDialogueService.participant(_speaker) == _player

## Выбирает ветку провокатора по постоянной особенности личности.
func dialogue_cue() -> String:
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id)
	if has_broken_promise():
		return "broken_promise"
	if can_offer_delivery():
		return "delivery_request"
	return "provocation" if person != null and person.profile.rule_for(DEF_NpcTrait.Kind.PROVOCATEUR) != null else "street"

## Возвращает отображаемое постоянное имя личности.
func speaker_name() -> String:
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id)
	return person.display_name if person != null else ""

## Интересы принадлежат личности независимо от обслуживания посылок.
func interests_text() -> String:
	var person: NpcRecord = NpcPopulationQueries.person_for(_person_id)
	return ", ".join(person.profile.interests) if person != null else ""

## Использует смысл наблюдаемого ответа; повтор выбора в фазе не перебрасывает реакцию.
func apply_response_tags(tags: PackedStringArray) -> bool:
	if not is_valid():
		return false

	var kind: CustomerDialogueIntent.Type = CustomerDialogueIntent.from_tags(tags)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var incident: StringName = StringName("street/%s/%d/%d/%d" % [_person_id, cycle.day_index, cycle.phase, kind])
	if tags.has("sub"):
		NpcSocialService.react(_speaker, _player, NpcMemory.Kind.SUBMISSION, incident)
	elif kind != CustomerDialogueIntent.Type.NONE:
		CustomerSocialService.dialogue_response(_speaker, _player, kind, incident)
	return true
#endregion
