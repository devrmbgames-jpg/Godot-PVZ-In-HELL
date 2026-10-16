extends Resource
## Один законченный или ожидающий возврата эпизод жизни; принадлежит NpcRecord внутри C_District.
class_name NpcDeathRecord

const SAVE_FIELDS: Array[String] = [
	"sequence", "day", "returned_day", "damage_type", "position",
	"actual_actor_id", "known_actor_id", "suspected_actor_id", "reaction",
	"response_given", "reaction_applied",
]

## Номер действительной смерти этой личности, начиная с единицы; не ID тела.
@export var sequence: int = 1
## Календарный день смерти; срок возврата вычисляется как day + 2.
@export var day: int = 1
## День действительного возврата; ноль, пока личность ожидает безопасного размещения.
@export var returned_day: int = 0
## Фактический тип последнего урона; сам по себе не раскрывает виновника.
@export var damage_type: DamageRequest.Type = DamageRequest.Type.GENERIC
## Известное погибшему место собственной смерти, в мировых метрах.
@export var position: Vector3 = Vector3.ZERO
## Фактический участник для истории; социальные решения не читают это поле.
@export var actual_actor_id: StringName = &""
## Распознанный через физическое зрение виновник; пусто при недостаточных сведениях.
@export var known_actor_id: StringName = &""
## Только ранее виденный противник; подозрение не становится доказанной обидой.
@export var suspected_actor_id: StringName = &""
## Единожды выбранная реакция характера на распознанного виновника.
@export var reaction: NpcMemory.Reaction = NpcMemory.Reaction.TALK
## Первая добровольная реплика о возвращении уже началась; повторное открытие её не повторяет.
@export var response_given: bool = false
## Первичная личная реакция уже применена; память не перезапускает погоню после её окончания.
@export var reaction_applied: bool = false
