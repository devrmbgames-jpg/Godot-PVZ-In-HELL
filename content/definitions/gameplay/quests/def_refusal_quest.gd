extends GameDefinition
## Авторские условия задания торговца на настоящий отказ в выдаче.
class_name DEF_RefusalQuest

## Награда за фактический отказ игрока в целых денежных единицах.
@export var reward: int = 60
## Минимум дней до срока; срок также покрывает назначенный визит.
@export_range(1, 30) var minimum_deadline_days: int = 1
