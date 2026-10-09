extends GameDefinition
## Авторские запуск, условие, завершение и последствия одноразового испытания.
class_name DEF_Challenge

enum Trigger { AFTER_DIALOGUE, ON_ARRIVAL }
enum Completion { ON_CONDITION, UNTIL_DEPARTURE, UNTIL_DEPARTURE_OR_FAILURE, SURVIVE_DURATION }

## Событие запроса запуска: после диалога либо при прибытии.
@export var trigger: Trigger = Trigger.AFTER_DIALOGUE
## Способ разрешения общего итога.
@export var completion: Completion = Completion.ON_CONDITION
## Авторское условие для специализированного вычислителя.
@export var condition: DEF_ChallengeCondition = null
## Понятное игроку правило для представления.
@export_multiline var rule_text: String = ""
## Длительность/лимит в секундах согласно completion; 0 отключает временной предел.
@export_range(0.0, 2400.0) var timeout_seconds: float = 80.0
## Срок показа принятого итога до очистки в секундах.
@export_range(0.0, 120.0) var result_display_seconds: float = 12.0
## Изменение удовлетворённости при успехе.
@export var success_satisfaction_delta: int = 10
## Изменение удовлетворённости при неудаче.
@export var failure_satisfaction_delta: int = -30
## Запрашивает боевую эскалацию после принятой неудачи.
@export var escalation_on_failure: bool = true
## Срок подготовки в секундах до накопления нарушения.
@export_range(0.0, 480.0) var preparation_seconds: float = 0.0
## Допуск накопленного нарушения в секундах.
@export_range(0.0, 120.0) var violation_grace_seconds: float = 4.0
## Соблюдение сбрасывает счётчик; уже зафиксированный факт нарушения сохраняется.
@export var reset_violation_on_compliance: bool = true
