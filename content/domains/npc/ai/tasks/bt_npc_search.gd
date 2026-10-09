@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Проверяет последний контакт и ближайшие авторские укрытия.

var _points: Array[Vector3] = []

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Поиск потерянной цели"):
		return FAILURE
	var segment: float = _person.profile.search_seconds / maxi(1, _person.profile.search_point_count)
	_awareness.search_index = mini(_person.profile.search_point_count - 1, int(_awareness.search_elapsed / segment))
	var index: int = clampi(_awareness.search_index, 0, _points.size() - 1)
	_move(_points[index], NpcDecisionService.ARRIVAL_DISTANCE)
	return RUNNING
func _enter() -> void:
	super._enter()
	_points = NpcDecisionService.search_points(_person, _awareness.last_seen_position)

#endregion
