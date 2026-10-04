extends RefCounted
## Однократный запрос перехода с защитой от устаревшего дня и фазы.
class_name DayTransitionRequest

enum Kind {
	START_SHIFT,
	FINISH_SHIFT,
	SLEEP,
}

## Запрошенный шаг цикла: начало, завершение смены или сон.
var kind: Kind = Kind.START_SHIFT
## День при создании запроса; несовпадение отклоняет устаревший запрос.
var expected_day: int = 0
## Фаза при создании запроса; проверяется и при отправке, и при исполнении.
var expected_phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
