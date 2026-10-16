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
			episode == null or episode.sequence != index + 1 or episode.day < 1
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
#endregion
