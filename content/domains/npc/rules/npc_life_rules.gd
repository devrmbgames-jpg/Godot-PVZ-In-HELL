extends RefCounted
## Чистые календарные правила авторской жизни; активные ticks и физическое тело не учитываются.
class_name NpcLifeRules

const RETURN_DELAY_DAYS: int = 2


#region Calendar and durable history
## Возвращение допускается только после двух переходов календарного дня текущей смерти.
static func return_due(person: NpcRecord, day: int) -> bool:
	return person.death_day > 0 and day >= person.death_day + RETURN_DELAY_DAYS


## Текущий либо ближайший номер смерти для однократного результата до/после mark_dead.
static func death_sequence_for(person: NpcRecord) -> int:
	return person.deaths.size() + (1 if person.death_day == 0 else 0)


## Проверяет последовательную историю и единственную текущую смерть без изменения состояния.
static func valid_history(person: NpcRecord, day: int) -> bool:
	var previous_return: int = 0
	for index: int in person.deaths.size():
		var episode: NpcDeathRecord = person.deaths[index]
		if (
			episode == null or not _valid_knowledge(episode, person.npc_id)
			or episode.sequence != index + 1 or episode.day < 1
			or episode.day > day or episode.day < previous_return
			or episode.returned_day < 0 or episode.returned_day > day
		):
			return false
		if episode.returned_day == 0:
			return index == person.deaths.size() - 1 and person.death_day == episode.day
		if episode.returned_day < episode.day + RETURN_DELAY_DAYS:
			return false
		previous_return = episode.returned_day
	return person.death_day == 0


## Самая ранняя нерассказанная история; unresolved эпизоды не удаляются коротким лимитом.
static func pending_response(person: NpcRecord) -> NpcDeathRecord:
	if person.death_day != 0:
		return null
	for episode: NpcDeathRecord in person.deaths:
		if episode.returned_day > 0 and not episode.response_given:
			return episode
	return null


## Читает эпизод по устойчивому номеру; UI хранит только borrowed номер открытой реплики.
static func episode_for(person: NpcRecord, sequence: int) -> NpcDeathRecord:
	if sequence < 1 or sequence > person.deaths.size():
		return null
	return person.deaths[sequence - 1]


## Мотив для единственной допустимой встречи; фактический скрытый источник не читается.
static func pending_conflict(person: NpcRecord, actor_id: StringName) -> bool:
	for episode: NpcDeathRecord in person.deaths:
		if (
			episode.returned_day > 0 and not episode.reaction_applied
			and episode.known_actor_id == actor_id and not actor_id.is_empty()
			and episode.reaction == NpcMemory.Reaction.ATTACK
		):
			return true
	return false


static func _valid_knowledge(episode: NpcDeathRecord, owner_id: StringName) -> bool:
	if (
		not episode.position.is_finite()
		or episode.damage_type < DamageRequest.Type.GENERIC
		or episode.damage_type > DamageRequest.Type.UNHOLY
		or episode.reaction < NpcMemory.Reaction.TALK
		or episode.reaction > NpcMemory.Reaction.RESPECT
		or not _valid_actor_id(episode.actual_actor_id)
		or not _valid_actor_id(episode.known_actor_id)
		or not _valid_actor_id(episode.suspected_actor_id)
		or episode.known_actor_id == owner_id or episode.suspected_actor_id == owner_id
	):
		return false
	if (
		not episode.known_actor_id.is_empty()
		and (
			episode.known_actor_id != episode.actual_actor_id
			or not episode.suspected_actor_id.is_empty()
		)
	):
		return false
	if episode.known_actor_id.is_empty() and episode.reaction != NpcMemory.Reaction.TALK:
		return false
	return (
		episode.returned_day != 0
		or (not episode.response_given and not episode.reaction_applied)
	)


static func _valid_actor_id(actor_id: StringName) -> bool:
	if actor_id.is_empty() or actor_id == &"player":
		return true
	var text: String = String(actor_id)
	var number: String = text.get_slice("/", 1)
	return (
		text.get_slice_count("/") == 2 and text.begins_with("npc/")
		and number.is_valid_int() and int(number) > 0 and str(int(number)) == number
	)
#endregion
