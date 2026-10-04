extends Component
## Факты и счётчики общего испытания; исполнение, эффекты и живые участники находятся отдельно.
class_name C_Challenge

enum Phase { INACTIVE, ARMED, ACTIVE, SUCCESS, FAILURE, CLEANUP }

## Авторские данные общего испытания.
@export var definition: DEF_Challenge = null
## Текущее состояние общего жизненного цикла.
var phase: Phase = Phase.INACTIVE
## Итог испытания, сохраняемый и после очистки участия.
var result: ChallengeResult.Type = ChallengeResult.Type.NONE
## Последнее измеренное выполнение условия, отдельно от общего итога.
var condition_result: ChallengeResult.Type = ChallengeResult.Type.NONE
## Однократный запуск уже принят; повторный arm запрещён.
var consumed: bool = false
## Прошедшее время активного испытания в секундах.
var elapsed: float = 0.0
## Накопленное время нарушения после подготовки в секундах.
var violation_elapsed: float = 0.0
## Нарушение уже достигло авторского допуска и остаётся фактом исхода.
var condition_violated: bool = false
## Запрос завершения условия до ухода участника.
var departure_requested: bool = false
## Остаток показа результата до очистки в секундах.
var result_remaining: float = 0.0
## День запуска для проверки живого сеанса.
var started_day: int = 0
## Фаза запуска; её смена отменяет сеанс.
var started_phase: C_DayCycle.Phase = C_DayCycle.Phase.DAY
## Типизированный итог для применения последствий.
var pending_result: ChallengeResolution = null
## Защита однократной попытки применения клиентских последствий.
var consequences_applied: bool = false
## Типизированный запрос эскалации для боевого адаптера, без отдельного владения боем/AI.
var escalation_request: ChallengeResolution = null
