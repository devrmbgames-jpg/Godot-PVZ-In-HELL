extends RefCounted
## Сохраняет только завершённые действия NEVER; длительность восстанавливается из авторского ресурса.
class_name PersistentInteractionState


#region Saved progress
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
	return valid_recipe(ids, _action_set(entity))


## Validates saved IDs against the final compiled action set without creating progress or effects.
static func valid_recipe(ids: Array, actions: C_InteractionActionSet) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for value: Variant in ids:
		if not value is StringName or seen.has(value):
			return false
		if _timing_in(actions, value as StringName) == null:
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

	state.actions.assign(recipe_for(ids, _action_set(entity)).actions)


## Builds private completed progress from authored actions without installing Components or effects.
static func recipe_for(ids: Array, actions: C_InteractionActionSet) -> C_ProlongedInteraction:
	var state: C_ProlongedInteraction = C_ProlongedInteraction.new()
	for action_id: StringName in ids:
		var timing: DEF_ProlongedInteraction = _timing_in(actions, action_id)
		assert(timing != null, "Validated completed progress requires its authored NEVER action")
		var progress: ProlongedInteractionProgress = ProlongedInteractionProgress.new()
		progress.action_id = action_id
		progress.timing = timing
		progress.fraction = ProlongedProgressSolver.COMPLETE_FRACTION
		progress.phase = ProlongedInteractionProgress.Phase.COMPLETED
		state.actions.append(progress)
	return state


## Сбрасывает незавершённый прогресс перед ночью, сохраняя завершённые действия.
static func reset_incomplete(entity: Entity) -> void:
	var state: C_ProlongedInteraction = entity.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state == null:
		return

	for progress: ProlongedInteractionProgress in state.actions:
		if progress != null and progress.phase != ProlongedInteractionProgress.Phase.COMPLETED:
			progress.fraction = 0.0
			progress.phase = ProlongedInteractionProgress.Phase.IDLE


#endregion

#region Authored action lookup
static func _action_set(entity: Entity) -> C_InteractionActionSet:
	var set: C_InteractionActionSet = entity.get_component(C_InteractionActionSet) as C_InteractionActionSet
	if set == null:
		for component: Component in entity.component_resources:
			if component is C_InteractionActionSet:
				set = component as C_InteractionActionSet
				break
	return set


static func _timing_in(actions: C_InteractionActionSet, id: StringName) -> DEF_ProlongedInteraction:
	if actions != null:
		for action: DEF_InteractionAction in actions.actions:
			if (action != null and action.action_id == id and action.timing != null
				and action.timing.reset_policy == DEF_ProlongedInteraction.ResetPolicy.NEVER):
				return action.timing
	return null

#endregion
