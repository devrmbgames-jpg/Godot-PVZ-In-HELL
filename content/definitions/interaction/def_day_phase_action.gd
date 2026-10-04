extends DEF_InteractionAction
## Отправляет запрос смены фазы с ожидаемыми днём и состоянием цикла.
class_name DEF_DayPhaseAction

## Авторский переход, который запрашивает это действие.
@export var transition: DayTransitionRequest.Kind = DayTransitionRequest.Kind.START_SHIFT


## Проверяет допустимость перехода из текущей фазы.
func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return DayPhaseService.permits(DayPhaseService.current(), transition)


## Отправляет запрос с текущими днём и фазой для защиты от устаревшего действия.
func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null:
		return

	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = transition
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	DayPhaseService.submit(request)
