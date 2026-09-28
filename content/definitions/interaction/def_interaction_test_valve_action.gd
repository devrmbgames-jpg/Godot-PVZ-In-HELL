extends DEF_InteractionAction
## Demo valve action: interaction completion emits the valve's scene signal.
class_name DEF_InteractionTestValveAction


func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	var valve: E_InteractionTestValve = source as E_InteractionTestValve
	if valve == null:
		return false
	if timing != null and timing.reset_policy == DEF_ProlongedInteraction.ResetPolicy.NEVER:
		var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(source, action_id)
		if progress != null and progress.phase == ProlongedInteractionProgress.Phase.COMPLETED:
			return false
	return true


func execute(_actor: Entity, source: Entity, _target: Entity) -> void:
	var valve: E_InteractionTestValve = source as E_InteractionTestValve
	if valve != null:
		valve.activate()
