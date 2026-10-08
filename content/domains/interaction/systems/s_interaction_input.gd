extends System
## Owns one interaction input step: capture priority, prolonged clock and explicit action dispatch.
class_name S_InteractionInput

const DROP_ORDER: Array[int] = [C_Grabbable.HoldSlot.CARRY, C_Grabbable.HoldSlot.LEFT_HAND, C_Grabbable.HoldSlot.RIGHT_HAND]

#region Scheduled input ownership
## Actor input/intent precedes targeting; physical proxy setup precedes commands; marker continuation follows.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_PlayerIntent, S_InteractionTargeting, S_Grab, S_ProlongedDecay], Runs.Before: [S_Marker]}


## Selects explicit input/control contracts, including disabled owners that still need cleanup.
func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_Interactor, C_GrabControl])


## Captures immutable input values and Component identity before the declared command-buffer boundary.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for actor: Entity in entities:
		var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
		var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
		var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
		cmd.add_custom(_consume_input.bind(weakref(actor), controller, interactor, control, InteractionInputSnapshot.capture(controller), delta))


func _consume_input(
	actor_reference: WeakRef, captured_controller: C_Controller, interactor: C_Interactor,
	control: C_GrabControl, controller: C_Controller, delta: float,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var actor: Entity = actor_reference.get_ref() as Entity

	# Deferred actors may have left the World or replaced their loaded/controller state.
	if not is_instance_valid(actor) or actor not in _world.entities or not actor.is_inside_tree():
		return
	if actor.get_component(C_Controller) != captured_controller or actor.get_component(C_Interactor) != interactor \
			or actor.get_component(C_GrabControl) != control or captured_controller.input_tick != controller.input_tick:
		return
	if controller.input_tick > 0 and interactor.last_action_tick == controller.input_tick:
		return

	interactor.last_action_tick = controller.input_tick
	for slot_index: int in 3:
		var held: Entity = GrabQueries.held_in_slot(actor, slot_index)
		if held == null:
			continue

		var body: RigidBody3D = GrabQueries.physical_body(held)
		var interactable: C_Interactable = held.get_component(C_Interactable) as C_Interactable
		if (
			not GrabQueries.holder_available(actor) or not GrabQueries.entity_available(held)
			or body == null or body.freeze
			or (interactable != null and not interactable.enabled)
		):
			GrabReleaseService.release(actor, held, false)
	if not GrabQueries.holder_available(actor):
		ProlongedInteractionService.cancel(actor)
		interactor.prompt_text = ""
		return

	_route_actions(actor, controller, control, delta)
#endregion

#region Capture priority and action arbitration
func _route_actions(actor: Entity, controller: C_Controller, control: C_GrabControl, delta: float) -> void:
	control.rotation_active = false
	if _advance_prolonged(actor, controller, delta):
		_refresh_prompt(actor)
		return

	var active_focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if active_focus >= InteractionControlFocus.Priority.DRAWING:
		_refresh_prompt(actor)
		return
	if active_focus == InteractionControlFocus.Priority.TRANSPORT:
		if controller.interact_pressed:
			InteractionActionResolver.execute_slot(actor, DEF_InteractionAction.Slot.INTERACT, true)
		elif controller.use_pressed:
			InteractionActionResolver.execute_slot(actor, DEF_InteractionAction.Slot.USE, true)
		_refresh_prompt(actor)
		return

	if active_focus == InteractionControlFocus.Priority.PUSH:
		if controller.interact_pressed or controller.move_axis.y > PushService.DIRECTION_EPSILON:
			InteractionActionResolver.execute_slot(actor, DEF_InteractionAction.Slot.INTERACT, true)
		elif controller.use_pressed:
			InteractionActionResolver.execute_slot(actor, DEF_InteractionAction.Slot.USE, true)
		_refresh_prompt(actor)
		return

	if controller.drop_long_pressed:
		control.context_wheel_requested = true

	elif controller.drop_pressed:
		control.context_wheel_requested = false
		for slot_index: int in DROP_ORDER:
			var dropped: Entity = GrabQueries.held_in_slot(actor, slot_index)
			if dropped != null:
				GrabReleaseService.release(actor, dropped)
				break

	elif controller.interact_pressed:
		InteractionActionResolver.execute_slot(actor, DEF_InteractionAction.Slot.INTERACT, true)

	elif controller.use_pressed:
		InteractionActionResolver.execute_slot(actor, DEF_InteractionAction.Slot.USE, true)

	else:
		# Приоритет фиксируется: освобождение Carry не передаёт тот же снимок ввода рукам.
		var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
		var primary_consumed: bool = InteractionActionResolver.execute_slot(
			actor,
			DEF_InteractionAction.Slot.PRIMARY,
			controller.action_main_pressed,
			controller.action_main,
		)

		if focus == InteractionControlFocus.current(actor):
			var secondary_consumed: bool = InteractionActionResolver.execute_slot(
				actor,
				DEF_InteractionAction.Slot.SECONDARY,
				controller.action_second_pressed,
				controller.action_second_held,
			)

			if not primary_consumed and not secondary_consumed and controller.rotate_held:
				var rotation: InteractionActionChoice = InteractionActionResolver.rotation_choice(actor)
				if rotation != null:
					rotation.action.execute(actor, rotation.source, rotation.target)

	_refresh_prompt(actor)



func _refresh_prompt(actor: Entity) -> void:
	# Explicit effects can remove the actor while this input step is executing.
	if EntityAvailability.contains(actor, _world) and actor.has_component(C_Interactor):
		InteractionActionResolver.refresh_prompt(actor)
#endregion

#region Active prolonged interaction clock
func _advance_prolonged(actor: Entity, controller: C_Controller, delta: float) -> bool:
	var binding: Relationship = ProlongedInteractionService.session(actor)
	if binding == null:
		return false

	var data: R_ProlongedOn = binding.relation as R_ProlongedOn
	if (
		not _held(controller, data.input_slot) or controller.cancel_pressed
		or not GrabQueries.holder_available(actor)
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.PROLONGED
	):
		ProlongedInteractionService.cancel(actor)
		return true

	var target: Entity = binding.target as Entity
	var source: Entity = ProlongedInteractionService.source_for(actor, target)
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(target, data.action.action_id)
	if (
		progress == null or not GrabQueries.entity_available(target)
		or not GrabQueries.entity_available(source)
	):
		ProlongedInteractionService.cancel(actor)
		return true
	# Повторный выбор исключает только свой токен; луч, сопоставление инструмента и другие захваты
	# сохраняют авторитетность без временного освобождения и повторного захвата управления.
	var choice: InteractionActionChoice = InteractionActionResolver.resolve(actor, data.input_slot, data.capture_token)
	if (
		choice == null or choice.action != data.action or choice.source != source
		or (choice.target if choice.target != null else choice.source) != target
	):
		ProlongedInteractionService.cancel(actor)
		return true
	if ProlongedProgressSolver.advance(progress, data.action.timing, delta, true):
		# Вложенное удаление эффектом освобождает участие, но не сбрасывает READY
		# до синхронной фиксации результата успешного завершения.
		data.finishing = true
		var success: bool = data.action.complete(actor, source, choice.target)
		data.finishing = false
		if success:
			ProlongedProgressSolver.commit_success(progress, data.action.timing)
		if not success or data.cleaned:
			ProlongedProgressSolver.interrupt(progress, data.action.timing)
			if ProlongedInteractionService.session(actor) == binding:
				ProlongedInteractionService.cancel(actor)
	return true


func _held(controller: C_Controller, slot: DEF_InteractionAction.Slot) -> bool:
	match slot:
		DEF_InteractionAction.Slot.INTERACT:
			return controller.interact_held

		DEF_InteractionAction.Slot.USE:
			return controller.use_held

		DEF_InteractionAction.Slot.PRIMARY:
			return controller.action_main

		DEF_InteractionAction.Slot.SECONDARY:
			return controller.action_second_held
	return false

#endregion
