extends GutTest
## Проверяет resolver длительных действий, захват ввода и освобождение живых Relationships.


## Управляемый эффект проверяет отказ, успех и отмену сессии из самого complete.
class ProbeAction extends DEF_InteractionAction:
	## Число попыток фиксации эффекта.
	var calls: int = 0
	## Доступность при последней повторной проверке.
	var allowed: bool = true
	## Результат тестовой попытки выполнить эффект.
	var succeeds: bool = true
	## Включает отмену сессии внутри эффекта для проверки повторного входа.
	var removes_session: bool = false
	## Starts a distinct authored action from inside completion to probe stale cleanup.
	var replacement_action: DEF_InteractionAction = null


	## Возвращает управляемую тестом доступность.
	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return allowed


	## Учитывает вызов и при необходимости отменяет сессию до возврата результата.
	func complete(actor: Entity, _source: Entity, _target: Entity) -> bool:
		calls += 1
		if removes_session:
			ProlongedInteractionService.cancel(actor)
		if replacement_action != null:
			(actor.get_component(C_InteractionActionSet) as C_InteractionActionSet).actions.assign([replacement_action])
			var choice: InteractionActionChoice = InteractionActionChoice.new()
			choice.action = replacement_action
			choice.source = actor
			choice.target = actor
			ProlongedInteractionService.begin(actor, choice, DEF_InteractionAction.Slot.PRIMARY)
		return succeeds


var _world: World
var _actor: Entity
var _controller: C_Controller
var _action: ProbeAction


#region Окружение и управляемое действие
## Создаёт отслеживаемое действие и владельца с реальными компонентами и observer lifecycle.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_ProlongedLifecycle.new())
	_action = ProbeAction.new()
	_action.action_id = &"probe"
	_action.slot = DEF_InteractionAction.Slot.PRIMARY
	_action.timing = DEF_ProlongedInteraction.new()
	_action.timing.duration_seconds = 1.5
	_action.timing.decay_per_second = 0.5
	_actor = _make_actor()
	_controller = _actor.get_component(C_Controller) as C_Controller

	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [_action]
	_actor.add_component(actions)


## Освобождает длительные связи всех участников до удаления World.
func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		ProlongedInteractionService.entity_unavailable(entity)
	_world.purge(false)
	_world.free()
	ECS.world = null


func _make_actor() -> Entity:
	var actor: Entity = Entity.new()
	actor.component_resources = [C_Controller.new(), C_Interactor.new(), C_GrabControl.new()]
	_world.add_child(actor)
	_world.add_entity(actor)
	return actor


func _start() -> void:
	_controller.action_main = true
	_controller.action_main_pressed = true
	_controller.input_tick += 1
	InteractionInputFixture.advance(_actor, 0.0)
	_controller.action_main_pressed = false
	assert_not_null(ProlongedInteractionService.session(_actor))


func _tick(delta: float) -> void:
	_controller.input_tick += 1
	InteractionInputFixture.advance(_actor, delta)


#endregion

#region Ввод и фиксация эффекта
## The completed callback can replace the session; cleanup may affect only its captured binding.
func test_completion_callback_can_begin_a_distinct_session_without_stale_cancellation() -> void:
	var replacement: ProbeAction = ProbeAction.new()
	replacement.action_id = &"replacement"
	replacement.slot = DEF_InteractionAction.Slot.PRIMARY
	replacement.timing = DEF_ProlongedInteraction.new()
	replacement.timing.duration_seconds = 2.0
	_action.removes_session = true
	_action.replacement_action = replacement
	_start()
	_tick(1.5)
	assert_eq(_action.calls, 1)
	var binding: Relationship = ProlongedInteractionService.session(_actor)
	assert_not_null(binding)
	assert_eq((binding.relation as R_ProlongedOn).action, replacement)
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.0)
	_tick(0.5)
	assert_eq(ProlongedInteractionService.session(_actor), binding)
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.25)
	assert_eq(replacement.calls, 0)


## Queued progression rejects a newer input tick and then resumes from that current snapshot.
func test_manual_flush_revalidates_input_tick() -> void:
	_start()
	var owner: S_InteractionInput = S_InteractionInput.new()
	owner.group = "manual_interaction"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_controller.input_tick += 1
	_world.process(0.75, owner.group)
	_controller.input_tick += 1
	_world.flush_command_buffers()
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.0)
	_world.process(0.75, owner.group)
	_world.flush_command_buffers()
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.5)


## A replaced input Component cannot inherit a queued command from the prior actor state.
func test_manual_flush_revalidates_loaded_controller_identity() -> void:
	_start()
	var owner: S_InteractionInput = S_InteractionInput.new()
	owner.group = "manual_interaction"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_controller.input_tick += 1
	_world.process(0.75, owner.group)
	var replacement: C_Controller = C_Controller.new()
	replacement.input_tick = _controller.input_tick
	replacement.action_main = true
	_actor.add_component(replacement)
	_world.flush_command_buffers()
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(ProlongedInteractionService.progress_for(_actor, &"probe").fraction, 0.0)
	assert_eq(_action.calls, 0)
	replacement.input_tick += 1
	replacement.action_main_pressed = true
	_world.process(0.0, owner.group)
	_world.flush_command_buffers()
	replacement.action_main_pressed = false
	replacement.input_tick += 1
	_world.process(0.75, owner.group)
	_world.flush_command_buffers()
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.5)


## The queued held intent is a copied value; subsequent mutation cannot rewrite it.
func test_manual_flush_uses_immutable_held_input_snapshot() -> void:
	_start()
	var owner: S_InteractionInput = S_InteractionInput.new()
	owner.group = "manual_interaction"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_controller.input_tick += 1
	_world.process(0.75, owner.group)
	_controller.action_main = false
	_world.flush_command_buffers()
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.5)
	_controller.input_tick += 1
	_world.process(0.0, owner.group)
	_world.flush_command_buffers()
	assert_null(ProlongedInteractionService.session(_actor))


## Завершение требует полной длительности; повторный запуск требует нового нажатия.
func test_completion_waits_for_duration_and_requires_new_press() -> void:
	_start()
	_tick(0.75)
	assert_eq(_action.calls, 0)
	assert_eq(ProlongedInteractionService.active_progress(_actor).fraction, 0.5)
	_tick(0.75)
	_tick(5.0)
	assert_eq(_action.calls, 1)
	_controller.action_main = false
	_tick(0.0)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	_controller.action_main = true
	_tick(5.0)
	assert_eq(_action.calls, 1, "Held state alone does not start another session")


## Повторная обработка одного input_tick не удваивает прогресс.
func test_duplicate_input_tick_does_not_advance_progress_twice() -> void:
	_start()
	_tick(0.5)
	InteractionInputFixture.advance(_actor, 1.0)
	assert_eq(_action.calls, 0)
	assert_almost_eq(ProlongedInteractionService.active_progress(_actor).fraction, 1.0 / 3.0, 0.0001)


## Модальный захват отменяет действие, сохраняя токен чужого владельца.
func test_modal_capture_interrupts_without_releasing_other_owner() -> void:
	_start()
	_tick(0.5)
	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	_tick(5.0)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(_action.calls, 0)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	InteractionControlFocus.release(_actor, token)


## Перед фиксацией повторно проверяется доступность эффекта.
func test_unavailable_action_never_executes_at_completion() -> void:
	_start()
	_tick(1.0)
	_action.allowed = false
	_tick(1.0)
	assert_eq(_action.calls, 0)
	assert_null(ProlongedInteractionService.session(_actor))


## Неуспешный эффект не расходует однократное действие NEVER.
func test_failed_effect_does_not_commit_never_policy() -> void:
	_action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.NEVER
	_action.succeeds = false
	_start()
	_tick(1.5)
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(_actor, &"probe")
	assert_eq(_action.calls, 1)
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.IDLE)
	assert_null(ProlongedInteractionService.session(_actor))


## Успех фиксируется и при отмене сессии самим эффектом.
func test_success_survives_reentrant_session_removal() -> void:
	_action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.NEVER
	_action.removes_session = true
	_start()
	_tick(1.5)
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(_actor, &"probe")
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.COMPLETED)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


#endregion

#region Владение и освобождение
## Одной целью владеет один участник; удаление цели освобождает обе живые связи.
func test_one_actor_per_target_and_target_removal_releases_both_relations() -> void:
	var target: Entity = _make_actor()
	var other: Entity = _make_actor()
	var choice: InteractionActionChoice = InteractionActionChoice.new()
	choice.action = _action
	choice.source = _actor
	choice.target = target
	assert_true(ProlongedInteractionService.begin(_actor, choice, DEF_InteractionAction.Slot.USE))
	choice.source = other
	assert_false(ProlongedInteractionService.begin(other, choice, DEF_InteractionAction.Slot.USE))
	_world.remove_entity(target)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_true(_actor.relationships.is_empty())
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


## Внешнее удаление сессии освобождает ввод и прерывает прогресс.
func test_external_relationship_removal_releases_capture() -> void:
	_start()
	_actor.remove_relationship(ProlongedInteractionService.session(_actor))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	assert_eq(ProlongedInteractionService.progress_for(_actor, &"probe").phase, ProlongedInteractionProgress.Phase.IDLE)


## Затухание незавершённой доли продолжается после отпускания кнопки.
func test_idle_decay_continues_after_release() -> void:
	_action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.DECAY
	_action.timing.decay_per_second = 0.25
	_start()
	_tick(0.75)
	_controller.action_main = false
	_tick(0.0)
	var state: C_ProlongedInteraction = _actor.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	InteractionInputFixture.decay(_actor, 1.0)
	assert_eq(state.actions[0].fraction, 0.25)


## Удаление связи с источником отключает подписку на исходный инструмент и освобождает сессию.
func test_external_source_relation_removal_disconnects_original_tool() -> void:
	var source: Entity = _make_actor()
	var target: Entity = _make_actor()
	var choice: InteractionActionChoice = InteractionActionChoice.new()
	choice.action = _action
	choice.source = source
	choice.target = target
	var original_connections: int = source.tree_exiting.get_connections().size()
	assert_true(ProlongedInteractionService.begin(_actor, choice, DEF_InteractionAction.Slot.USE))
	assert_eq(source.tree_exiting.get_connections().size(), original_connections + 1)
	for binding: Relationship in _actor.relationships.duplicate():
		if binding.relation is R_ProlongedUsing:
			_actor.remove_relationship(binding)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(source.tree_exiting.get_connections().size(), original_connections)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


## Удаление обязательного компонента игрока не оставляет блокировку сессии.
func test_removing_required_actor_component_cannot_leave_a_session_lock() -> void:
	_start()
	_actor.remove_component(_controller)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)

#endregion
