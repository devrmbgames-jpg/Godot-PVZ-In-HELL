extends GutTest
## Deterministic integration of the resolver, capture and real GECS relationships.


class ProbeAction extends DEF_InteractionAction:
	var calls: int = 0
	var allowed: bool = true
	var succeeds: bool = true
	var removes_session: bool = false


	func is_available(_actor: Entity, _source: Entity, _target: Entity) -> bool:
		return allowed


	func complete(actor: Entity, _source: Entity, _target: Entity) -> bool:
		calls += 1
		if removes_session:
			ProlongedInteractionService.cancel(actor)
		return succeeds


var _world: World
var _actor: Entity
var _controller: C_Controller
var _action: ProbeAction


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_observer(O_ProlongedLifecycle.new())
	_action = ProbeAction.new()
	_action.action_id = &"probe"
	_action.slot = DEF_InteractionAction.Slot.PRIMARY
	_action.timing = DEF_ProlongedInteraction.new()
	_actor = _make_actor()
	_controller = _actor.get_component(C_Controller) as C_Controller
	var actions: C_InteractionActionSet = C_InteractionActionSet.new()
	actions.actions = [_action]
	_actor.add_component(actions)


func after_each() -> void:
	for entity: Entity in _world.entities.duplicate():
		ProlongedInteractionService.entity_unavailable(entity)
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
	InteractionActionResolver.handle_input(_actor, 0.0)
	_controller.action_main_pressed = false
	assert_not_null(ProlongedInteractionService.session(_actor))


func _tick(delta: float) -> void:
	_controller.input_tick += 1
	InteractionActionResolver.handle_input(_actor, delta)


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


func test_duplicate_input_tick_does_not_advance_progress_twice() -> void:
	_start()
	_tick(0.5)
	InteractionActionResolver.handle_input(_actor, 1.0)
	assert_eq(_action.calls, 0)
	assert_almost_eq(ProlongedInteractionService.active_progress(_actor).fraction, 1.0 / 3.0, 0.0001)


func test_modal_capture_interrupts_without_releasing_other_owner() -> void:
	_start()
	_tick(0.5)
	var token: int = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	_tick(5.0)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(_action.calls, 0)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.MODAL)
	InteractionControlFocus.release(_actor, token)


func test_unavailable_action_never_executes_at_completion() -> void:
	_start()
	_tick(1.0)
	_action.allowed = false
	_tick(1.0)
	assert_eq(_action.calls, 0)
	assert_null(ProlongedInteractionService.session(_actor))


func test_failed_effect_does_not_commit_never_policy() -> void:
	_action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.NEVER
	_action.succeeds = false
	_start()
	_tick(1.5)
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(_actor, &"probe")
	assert_eq(_action.calls, 1)
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.IDLE)
	assert_null(ProlongedInteractionService.session(_actor))


func test_success_survives_reentrant_session_removal() -> void:
	_action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.NEVER
	_action.removes_session = true
	_start()
	_tick(1.5)
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(_actor, &"probe")
	assert_eq(progress.phase, ProlongedInteractionProgress.Phase.COMPLETED)
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)


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


func test_external_relationship_removal_releases_capture() -> void:
	_start()
	_actor.remove_relationship(ProlongedInteractionService.session(_actor))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
	assert_eq(ProlongedInteractionService.progress_for(_actor, &"probe").phase, ProlongedInteractionProgress.Phase.IDLE)


func test_idle_decay_continues_after_release() -> void:
	_action.timing.reset_policy = DEF_ProlongedInteraction.ResetPolicy.DECAY
	_action.timing.decay_per_second = 0.25
	_start()
	_tick(0.75)
	_controller.action_main = false
	_tick(0.0)
	var state: C_ProlongedInteraction = _actor.get_component(C_ProlongedInteraction) as C_ProlongedInteraction
	ProlongedInteractionService.decay(state, 1.0)
	assert_eq(state.actions[0].fraction, 0.25)


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


func test_removing_required_actor_component_cannot_leave_a_session_lock() -> void:
	_start()
	_actor.remove_component(_controller)
	assert_null(ProlongedInteractionService.session(_actor))
	assert_eq(InteractionControlFocus.current(_actor), InteractionControlFocus.Priority.HANDS)
