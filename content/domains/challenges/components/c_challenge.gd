extends Component
## ChallengeService owns session lifecycle; S_ChallengeRuntime owns gameplay clocks.
## Conditions пишут специализированные Systems; live actor/effect принадлежат Relationships.
## Codec не сохраняет этот Component; постоянные customer consequences записываются в CustomerVisit.
class_name C_Challenge

enum Phase {
	INACTIVE,
	ARMED,
	ACTIVE,
	SUCCESS,
	FAILURE,
	CLEANUP,
}

## Immutable Definition reference; composition/service role selects it, debug_start may override.
@export var definition: DEF_Challenge = null
## Текущее состояние общего жизненного цикла.
var phase: Phase = Phase.INACTIVE
## ChallengeService сохраняет итог после cleanup в этом Component; это не Night-persistent history.
var result: ChallengeResult.Type = ChallengeResult.Type.NONE
## S_ChallengeGaze/S_ChallengeLight/S_FloorHazard пишут измерение своего condition, не общий итог.
var condition_result: ChallengeResult.Type = ChallengeResult.Type.NONE
## Однократный запуск уже принят; повторный arm запрещён.
var consumed: bool = false
## S_ChallengeRuntime увеличивает gameplay seconds ACTIVE; service сбрасывает при activate/cleanup.
var elapsed: float = 0.0
## S_ChallengeRuntime копит gameplay seconds нарушения после подготовки; compliance может обнулить.
var violation_elapsed: float = 0.0
## Нарушение уже достигло авторского допуска и остаётся фактом исхода.
var condition_violated: bool = false
## Запрос завершения условия до ухода участника.
var departure_requested: bool = false
## Service задаёт при resolve, S_ChallengeRuntime уменьшает gameplay seconds до cleanup.
var result_remaining: float = 0.0
## День запуска для проверки живого сеанса.
var started_day: int = 0
## Фаза запуска; её смена отменяет сеанс.
var started_phase: C_DayCycle.Phase = C_DayCycle.Phase.DAY
## ChallengeService.resolve создаёт payload; O_CustomerChallengeOutcome проверяет его identity.
var pending_result: ChallengeResolution = null
## O_CustomerChallengeOutcome отмечает единственную попытку применить результат к живому визиту.
var consequences_applied: bool = false
## O_CustomerChallengeOutcome пишет, S_CustomerCombat потребляет; запрос не владеет боем/AI.
var escalation_request: ChallengeResolution = null
