extends RefCounted
## Владеет длительными сеансами и синхронным завершением эффекта на границе команды ввода.
class_name ProlongedInteractionService


#region Чтение и начало сеанса
## Возвращает живую связь R_ProlongedOn актора, если сеанс существует.
static func session(actor: Entity) -> Relationship:
	if is_instance_valid(actor):
		for binding: Relationship in actor.relationships:
			if binding.relation is R_ProlongedOn:
				return binding
	return null


## Читает сохраняемый прогресс конкретного action_id на цели.
static func progress_for(target: Entity, action_id: StringName) -> ProlongedInteractionProgress:
	if not is_instance_valid(target):
		return null

	var state: C_ProlongedInteraction = target.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state != null:
		for progress: ProlongedInteractionProgress in state.actions:
			if progress.action_id == action_id:
				return progress
	return null


## Задаёт отладочный прогресс 0–1, не перехватывая активный сеанс и не возобновляя завершённое действие.
static func debug_set_progress(target: Entity, action: DEF_InteractionAction, value: float) -> bool:
	if not EntityAvailability.contains(target, ECS.world) or action == null or action.timing == null or action.action_id == &"" or not is_finite(value) or value < 0.0 or value > 1.0:
		return false

	for actor: Entity in ECS.world.entities:
		var binding: Relationship = session(actor)
		if binding != null and binding.target == target:
			return false

	var progress: ProlongedInteractionProgress = progress_for(target, action.action_id)
	if progress != null and (progress.phase == ProlongedInteractionProgress.Phase.COMPLETED or progress.timing != action.timing):
		return false
	if progress == null:
		var state: C_ProlongedInteraction = target.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
		if state == null:
			state = C_ProlongedInteraction.new()
			target.add_component(state)
		progress = ProlongedInteractionProgress.new()
		progress.action_id = action.action_id
		progress.timing = action.timing
		state.actions.append(progress)
	progress.fraction = value
	progress.phase = ProlongedInteractionProgress.Phase.IDLE
	return true


## Читает прогресс действия текущего живого сеанса актора.
static func active_progress(actor: Entity) -> ProlongedInteractionProgress:
	var binding: Relationship = session(actor)
	if binding == null:
		return null

	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	return progress_for(binding.target as Entity, data.action.action_id)


## Проверяет участников и свободную цель, создаёт связи и захватывает приоритет PROLONGED.
static func begin(actor: Entity, choice: InteractionActionChoice, slot: DEF_InteractionAction.Slot) -> bool:
	if choice == null or choice.action == null or session(actor) != null:
		return false

	var action: DEF_InteractionAction = choice.action
	var target: Entity = choice.target if choice.target != null else choice.source
	if (
		not GrabQueries.holder_available(actor) or not GrabQueries.entity_available(target)
		or not GrabQueries.entity_available(choice.source) or action.action_id == &""
		or action.timing == null or not action.is_available(actor, choice.source, choice.target)
		or InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PROLONGED
	):
		return false
	if not is_finite(action.timing.duration_seconds) or action.timing.duration_seconds <= 0.0:
		return false
	if (
		not is_finite(action.timing.decay_per_second) or action.timing.decay_per_second < 0.0
		or action.timing.reset_policy < DEF_ProlongedInteraction.ResetPolicy.DECAY
		or action.timing.reset_policy > DEF_ProlongedInteraction.ResetPolicy.NEVER
	):
		return false
	if not is_instance_valid(ECS.world):
		return false

	for other: Entity in ECS.world.entities:
		var occupied: Relationship = session(other)
		if occupied != null and occupied.target == target:
			return false

	var state: C_ProlongedInteraction = target.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	if state == null:
		state = C_ProlongedInteraction.new()
		target.add_component(state)
	var progress: ProlongedInteractionProgress = progress_for(target, action.action_id)
	if progress == null:
		progress = ProlongedInteractionProgress.new()
		progress.action_id = action.action_id
		progress.timing = action.timing
		state.actions.append(progress)
	if progress.timing != action.timing or progress.phase in [ProlongedInteractionProgress.Phase.COMPLETED, ProlongedInteractionProgress.Phase.READY]:
		return false

	var data: R_ProlongedOn = R_ProlongedOn.new()
	data.action = action
	data.input_slot = slot
	data.capture_token = InteractionControlFocus.acquire(actor, target, InteractionControlFocus.Priority.PROLONGED)
	if data.capture_token == 0:
		return false

	var binding: Relationship = Relationship.new(data, target)
	actor.add_relationship(binding)
	if choice.source != target:
		actor.add_relationship(Relationship.new(R_ProlongedUsing.new(), choice.source))
	var cleanup: Callable = _cancel_session.bind(actor, binding)
	for participant: Entity in [actor, target, choice.source]:
		if not participant.tree_exiting.is_connected(cleanup):
			participant.tree_exiting.connect(cleanup)
	return true


#endregion

#region Исполнение и освобождение участия
## Очищает ресурсы сеанса и удаляет его связь; повтор безопасен.
static func cancel(actor: Entity) -> void:
	var binding: Relationship = session(actor)
	if binding != null:
		# Очистка предшествует удалению: наблюдатель связи может безопасно повторить её.
		removed(actor, binding)
		actor.remove_relationship(binding)


## Освобождает токен и обработчики удалённой связи однократно, учитывая завершение эффекта.
static func removed(actor: Entity, binding: Relationship) -> void:
	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	if data == null or data.cleaned:
		return

	data.cleaned = true
	var target: Entity = binding.target as Entity
	var source: Entity = source_for(actor, target)
	var cleanup: Callable = _cancel_session.bind(actor, binding)
	for participant: Entity in [actor, target, source]:
		if is_instance_valid(participant) and participant.tree_exiting.is_connected(cleanup):
			participant.tree_exiting.disconnect(cleanup)
	var progress: ProlongedInteractionProgress = progress_for(target, data.action.action_id)
	if progress != null and not data.finishing:
		ProlongedProgressSolver.interrupt(progress, data.action.timing)
	InteractionControlFocus.release(actor, data.capture_token)
	for relation: Relationship in actor.relationships.duplicate():
		if relation.relation is R_ProlongedUsing:
			actor.remove_relationship(relation)


## Отменяет сеансы, в которых сущность является актором, целью или инструментом.
static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(ECS.world):
		return

	cancel(entity)
	for actor: Entity in ECS.world.entities.duplicate():
		var binding: Relationship = session(actor)
		if binding != null and (binding.target == entity or source_for(actor, binding.target as Entity) == entity):
			cancel(actor)


## Вызывается после удаления R_ProlongedUsing из GECS; payload сохраняет источник,
## чтобы отключить старый обработчик tree_exiting и завершить сеанс.
static func source_removed(actor: Entity, source_binding: Relationship) -> void:
	var binding: Relationship = session(actor)
	if binding == null:
		return

	var source: Entity = source_binding.target as Entity
	var cleanup: Callable = _cancel_session.bind(actor, binding)
	if is_instance_valid(source) and source.tree_exiting.is_connected(cleanup):
		source.tree_exiting.disconnect(cleanup)
	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	if data.cleaned:
		return

	cancel(actor)


#endregion

#region Живые связи и канал ввода
## Resolves the authoritative live tool relationship, otherwise the target itself.
static func source_for(actor: Entity, target: Entity) -> Entity:
	for binding: Relationship in actor.relationships:
		if binding.relation is R_ProlongedUsing:
			return binding.target as Entity
	return target


static func _cancel_session(actor: Entity, binding: Relationship) -> void:
	if session(actor) == binding:
		cancel(actor)


#endregion
