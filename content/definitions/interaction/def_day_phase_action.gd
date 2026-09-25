extends DEF_InteractionAction
## Requests a validated transition of the warehouse day phase.
class_name DEF_DayPhaseAction

@export var transition: DayTransitionRequest.Kind = DayTransitionRequest.Kind.START_SHIFT


func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return DayPhaseService.permits(DayPhaseService.current(), transition)


func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null:
		return
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = transition
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	DayPhaseService.submit(request)
