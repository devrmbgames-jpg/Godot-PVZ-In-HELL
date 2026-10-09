extends DEF_InteractionAction
## Демонстрирует длительное действие и политики сброса в сцене тестового вентиля.
class_name DEF_InteractionTestValveAction

## Режим вентиля, которому соответствует действие; несовпадение скрывает команду.
@export var mode: E_InteractionTestValve.Mode = E_InteractionTestValve.Mode.IMMEDIATE_E


## Проверяет режим и исключает повтор завершённого действия при политике NEVER.
func is_available(_actor: Entity, source: Entity, _target: Entity) -> bool:
	var valve: E_InteractionTestValve = source as E_InteractionTestValve
	if valve == null or valve.mode != mode:
		return false
	if timing != null and timing.reset_policy == DEF_ProlongedInteraction.ResetPolicy.NEVER:
		var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(
			source,
			action_id,
		)
		if progress != null and progress.phase == ProlongedInteractionProgress.Phase.COMPLETED:
			return false
	return true


## Активирует вентиль; длительность и завершение контролирует общий контур.
func execute(_actor: Entity, source: Entity, _target: Entity) -> void:
	var valve: E_InteractionTestValve = source as E_InteractionTestValve
	if valve != null:
		valve.activate()
