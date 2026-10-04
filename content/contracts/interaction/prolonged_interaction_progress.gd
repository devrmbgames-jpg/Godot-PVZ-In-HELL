extends Resource
## Сохраняемый прогресс действия на цели; живые участники и управление UI здесь не хранятся.
class_name ProlongedInteractionProgress

enum Phase { IDLE, ADVANCING, READY, WAITING_FOR_RELEASE, COMPLETED }

## Постоянный ID действия, связывающий его с прогрессом на цели.
@export var action_id: StringName = &""
## Авторские длительность и правила сброса/затухания.
@export var timing: DEF_ProlongedInteraction = null
## Сохранённая доля выполнения, 0–1.
@export_range(0.0, 1.0) var fraction: float = 0.0
## Фаза прогресса без ссылок на живого участника.
@export var phase: Phase = Phase.IDLE
