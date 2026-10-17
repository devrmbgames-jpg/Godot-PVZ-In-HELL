extends RefCounted
## Завершённое возвращение прежнего тела; потребители возобновляют собственные обязательства.
class_name NpcReturnCommitted

## Канал факта после восстановления жизни, размещения и нативного дерева.
const EVENT: StringName = &"npc_return_committed"
## Точный агрегат района для отбрасывания отложенного факта после reconstruction.
var district: C_District
## Постоянная личность, завершившая этот эпизод отсутствия.
var npc_id: StringName
## Номер завершённого эпизода; не общий таймер или новая запись жизни.
var sequence: int
## Фактический день возвращения, включая подготовленное ночью будущее утро.
var day_index: int


#region Создание факта
func _init(owner: C_District, person: NpcRecord, day: int) -> void:
	district = owner
	npc_id = person.npc_id
	sequence = person.deaths.back().sequence
	day_index = day
#endregion
