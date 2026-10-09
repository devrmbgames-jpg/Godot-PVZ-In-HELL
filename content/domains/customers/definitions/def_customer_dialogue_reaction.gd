extends Resource
## Авторская реакция политики обслуживания на смысл ответа игрока, без исполнения действий.
class_name DEF_CustomerDialogueReaction

## Смысл ответа, к которому применяется эта реакция.
@export var intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.Type.NONE
## Изменение удовлетворённости, в пунктах шкалы 0–100.
@export_range(-100, 100, 1) var satisfaction_delta: int = 0
## Добавка к вероятности жалобы; итоговая вероятность ограничивается 0–1.
@export_range(-1.0, 1.0, 0.05) var complaint_probability_delta: float = 0.0
## Добавка к вероятности агрессии; итоговая вероятность ограничивается 0–1.
@export_range(-1.0, 1.0, 0.05) var aggression_probability_delta: float = 0.0
## Добавка к вероятности повторного визита; итоговая вероятность ограничивается 0–1.
@export_range(-1.0, 1.0, 0.05) var followup_probability_delta: float = 0.0
