extends GameDefinition
## Авторские условия задания торговца на настоящий отказ в выдаче.
class_name DEF_RefusalQuest

## Награда за фактический отказ игрока в целых денежных единицах.
@export var reward: int = 60
## Минимум дней до срока; срок также покрывает назначенный визит.
@export_range(1, 30) var minimum_deadline_days: int = 1

## Authored offer text with fixed number/deadline/days/reward formatting fields.
@export_multiline var offer_text: String = "Задание: не выдавай посылку №{number}.\nСрок: до Night дня {deadline} (осталось {days} дней). Награда {reward} за настоящий отказ. Обычные штрафы и жалобы сохраняются."
## Authored accepted-state reminder; gameplay resolution still reads actual customer outcome.
@export_multiline var accepted_text: String = "Задание принято. Отказ в Terminal без реального отказа клиенту не выполняет задачу."
## Caption for the explicit accept command.
@export var accept_text: String = "Принять задание"
## Caption for the explicit ignore command.
@export var ignore_text: String = "Отказаться от задания"
