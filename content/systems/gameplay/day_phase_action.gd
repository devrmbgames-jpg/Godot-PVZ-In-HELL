extends InteractionAction
class_name DayPhaseAction

@export var transition: DayTransitionRequest.Kind = DayTransitionRequest.Kind.START_SHIFT


func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
	return S_DayPhase.permits(S_DayPhase.current(), transition)


func execute(_actor: Entity, _source: Entity, _target: Entity) -> void:
	var cycle: C_DayCycle = S_DayPhase.current()
	if cycle == null:
		return
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = transition
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	S_DayPhase.submit(request)
