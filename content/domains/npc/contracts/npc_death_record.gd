extends Resource
## Один законченный или ожидающий возврата эпизод жизни; принадлежит NpcRecord внутри C_District.
class_name NpcDeathRecord

const SAVE_FIELDS: Array[String] = ["sequence", "day", "returned_day"]

## Номер действительной смерти этой личности, начиная с единицы; не ID тела.
@export var sequence: int = 1
## Календарный день смерти; срок возврата вычисляется как day + 2.
@export var day: int = 1
## День действительного возврата; ноль, пока личность ожидает безопасного размещения.
@export var returned_day: int = 0
