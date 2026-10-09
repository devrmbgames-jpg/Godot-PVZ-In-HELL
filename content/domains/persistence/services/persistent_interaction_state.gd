extends RefCounted
## Сохраняет только завершённые действия NEVER; длительность восстанавливается из авторского ресурса.
class_name PersistentInteractionState


## Возвращает ID только завершённых действий с политикой NEVER.
static func completed(entity: Entity) -> Array[StringName]:
	var ids: Array[StringName] = []
	var state: C_ProlongedInteraction = entity.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state != null:
		for progress: ProlongedInteractionProgress in state.actions:
			if progress != null and progress.timing != null and progress.timing.reset_policy == DEF_ProlongedInteraction.ResetPolicy.NEVER and progress.phase == ProlongedInteractionProgress.Phase.COMPLETED:
				ids.append(progress.action_id)
	return ids


## Проверяет уникальные ID и соответствие авторским действиям NEVER.
static func valid(ids: Array, entity: Entity) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for value: Variant in ids:
		if not value is StringName or seen.has(value) or _timing(entity, value as StringName) == null:
			return false

		seen[value] = true
	return true


## Заменяет прогресс только сохранёнными завершёнными действиями без повторного эффекта.
static func restore(ids: Array, entity: Entity) -> void:
	var state: C_ProlongedInteraction = entity.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state == null and not ids.is_empty():
		state = C_ProlongedInteraction.new()
		entity.add_component(state)
	if state == null:
		return

	state.actions.clear()
	for id: StringName in ids:
		var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
		progress.action_id = id
		progress.timing = _timing(entity, id)
		progress.fraction = ProlongedProgressSolver.COMPLETE_FRACTION
		progress.phase = ProlongedInteractionProgress.Phase.COMPLETED
		state.actions.append(progress)


## Сбрасывает незавершённый прогресс перед ночью, сохраняя завершённые действия.
static func reset_incomplete(entity: Entity) -> void:
	var state: C_ProlongedInteraction = entity.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state == null:
		return

	for progress: ProlongedInteractionProgress in state.actions:
		if progress != null and progress.phase != ProlongedInteractionProgress.Phase.COMPLETED:
			progress.fraction = 0.0
			progress.phase = ProlongedInteractionProgress.Phase.IDLE


static func _timing(entity: Entity, id: StringName) -> DEF_ProlongedInteraction:
	var set: C_InteractionActionSet = entity.get_component(C_InteractionActionSet) as C_InteractionActionSet
	if set == null:
		for component: Component in entity.component_resources:
			if component is C_InteractionActionSet:
				set = component as C_InteractionActionSet
				break
	if set != null:
		for action: DEF_InteractionAction in set.actions:
			if action != null and action.action_id == id and action.timing != null and action.timing.reset_policy == DEF_ProlongedInteraction.ResetPolicy.NEVER:
				return action.timing
	return null
