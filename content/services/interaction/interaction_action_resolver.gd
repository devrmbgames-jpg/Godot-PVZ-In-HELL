extends RefCounted
## Routes interaction input and prompts through control focus and physical hand mapping.
class_name InteractionActionResolver

const BUTTON_LABELS: Array[String] = ["E", "F", "ЛКМ", "ПКМ"]
const INPUT_ACTIONS: Array[StringName] = [
	&"interact",
	&"use",
	&"action_primary",
	&"action_secondary",
]
const DROP_ORDER: Array[int] = [
	C_Grabbable.HoldSlot.CARRY,
	C_Grabbable.HoldSlot.LEFT_HAND,
	C_Grabbable.HoldSlot.RIGHT_HAND,
]


#region Public API
## Routes one deduplicated input tick without leaking captured buttons to lower priorities.
static func handle_input(actor: Entity) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	if controller.input_tick > 0 and interactor.last_action_tick == controller.input_tick:
		return

	interactor.last_action_tick = controller.input_tick
	control.rotation_active = false
	var active_focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if active_focus >= InteractionControlFocus.Priority.DRAWING:
		refresh_prompt(actor)
		return
	if active_focus == InteractionControlFocus.Priority.TRANSPORT:
		if controller.interact_pressed:
			_execute_slot(actor, DEF_InteractionAction.Slot.INTERACT, true)
		elif controller.use_pressed:
			_execute_slot(actor, DEF_InteractionAction.Slot.USE, true)
		refresh_prompt(actor)
		return

	if active_focus == InteractionControlFocus.Priority.PUSH:
		if controller.interact_pressed or controller.move_axis.y > S_Push.DIRECTION_EPSILON:
			_execute_slot(actor, DEF_InteractionAction.Slot.INTERACT, true)
		elif controller.use_pressed:
			_execute_slot(actor, DEF_InteractionAction.Slot.USE, true)
		refresh_prompt(actor)
		return

	if controller.drop_long_pressed:
		control.context_wheel_requested = true

	elif controller.drop_pressed:
		control.context_wheel_requested = false
		for slot_index: int in DROP_ORDER:
			var dropped: Entity = S_Grab.held_in_slot(actor, slot_index)
			if dropped != null:
				S_Grab.release(actor, dropped)
				break

	elif controller.interact_pressed:
		_execute_slot(actor, DEF_InteractionAction.Slot.INTERACT, true)

	elif controller.use_pressed:
		_execute_slot(actor, DEF_InteractionAction.Slot.USE, true)

	else:
		# Snapshot focus: releasing Carry cannot route this same tick into hands.
		var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
		var primary_consumed: bool = _execute_slot(
			actor,
			DEF_InteractionAction.Slot.PRIMARY,
			controller.action_main_pressed,
			controller.action_main,
		)

		if focus == InteractionControlFocus.current(actor):
			var secondary_consumed: bool = _execute_slot(
				actor,
				DEF_InteractionAction.Slot.SECONDARY,
				controller.action_second_pressed,
				controller.action_second_held,
			)

			if not primary_consumed and not secondary_consumed and controller.rotate_held:
				var rotation: InteractionActionChoice = rotation_choice(actor)
				if rotation != null:
					rotation.action.execute(actor, rotation.source, rotation.target)

	refresh_prompt(actor)


## Returns the highest-priority available action for this input slot without executing it.
static func resolve(
	actor: Entity,
	input_slot: DEF_InteractionAction.Slot,
) -> InteractionActionChoice:
	if not S_Grab.holder_available(actor):
		return null

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	if interactor == null or controller == null:
		return null

	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus >= InteractionControlFocus.Priority.DRAWING:
		return null

	var target: Entity = interactor.target if is_instance_valid(interactor.target) else null
	if target != null and S_InteractionTargeting.find_target(actor, interactor) != target:
		target = null
	var physics_target: RigidBody3D = (
		interactor.physics_target if is_instance_valid(interactor.physics_target) else null
	)
	if (
		physics_target != null
		and S_InteractionTargeting.find_physics_target(actor, interactor) != physics_target
	):
		physics_target = null
	if focus == InteractionControlFocus.Priority.TRANSPORT:
		if input_slot == DEF_InteractionAction.Slot.INTERACT:
			var cart: Entity = CartTransportService.current(actor)
			if cart == null:
				return null
			var stop: DEF_CartTransportAction = DEF_CartTransportAction.new()
			stop.release_handle = true
			stop.caption = "Отпустить ручку"
			return _choice(stop, cart, target)
		if input_slot == DEF_InteractionAction.Slot.USE:
			return _target_action(actor, target, input_slot)
		return null

	if focus == InteractionControlFocus.Priority.PUSH:
		if input_slot == DEF_InteractionAction.Slot.INTERACT:
			var cart: Entity = S_Push.pushed_object(actor)
			if cart == null:
				return null
			var stop: DEF_PushAction = DEF_PushAction.new()
			stop.end_push = true
			stop.caption = "Отпустить тележку"
			return _choice(stop, cart, target)
		if input_slot == DEF_InteractionAction.Slot.USE:
			return _target_action(actor, target, input_slot)
		return null

	var carry: Entity = S_Grab.held_in_slot(actor, C_Grabbable.HoldSlot.CARRY)
	if focus == InteractionControlFocus.Priority.CARRY:
		if input_slot == DEF_InteractionAction.Slot.INTERACT:
			return _physical(actor, carry, DEF_GrabAction.Kind.RELEASE)

		if input_slot == DEF_InteractionAction.Slot.PRIMARY:
			return _physical(actor, carry, DEF_GrabAction.Kind.THROW)

		if input_slot == DEF_InteractionAction.Slot.SECONDARY:
			return _physical(actor, carry, DEF_GrabAction.Kind.ROTATE)

		var target_action: InteractionActionChoice = _target_action(actor, target, input_slot)
		if target_action != null:
			return target_action
		return _from_source(actor, carry, carry, input_slot)

	if (
		input_slot == DEF_InteractionAction.Slot.INTERACT
		or input_slot == DEF_InteractionAction.Slot.USE
	):
		var target_action: InteractionActionChoice = _target_action(actor, target, input_slot)
		var authored_grab: bool = (
			target != null
			and (target.get_component(C_Grabbable) as C_Grabbable) != null
			and S_Grab.physical_body(target) == physics_target
		)
		# Explicit gameplay actions keep priority unless this Entity authored Grab behavior.
		if target_action != null and not authored_grab:
			return target_action

		var selected: int = S_Grab.pickup_slot_for_body(
			actor,
			physics_target,
			input_slot == DEF_InteractionAction.Slot.USE,
		)
		var replace: bool = selected != C_Grabbable.HoldSlot.CARRY
		var handle: Entity = PhysicsGrabTarget.handle_for(physics_target, false)
		if S_Grab.can_pickup_body(actor, physics_target, selected, replace, handle):
			var pickup: DEF_GrabAction = DEF_GrabAction.new()
			pickup.kind = DEF_GrabAction.Kind.PICKUP
			pickup.hold_slot = selected
			pickup.replace_occupant = replace
			pickup.physical_body = physics_target
			pickup.caption = "Заменить" if S_Grab.held_in_slot(actor, selected) != null else "Взять"

			if selected != C_Grabbable.HoldSlot.CARRY:
				var right_hand: bool = selected == C_Grabbable.HoldSlot.RIGHT_HAND
				pickup.caption += " · правая рука" if right_hand else " · левая рука"

			return _choice(pickup, handle, target)
		return target_action


	var held: Entity = S_Grab.held_in_slot(
		actor,
		S_Grab.mapped_hand(actor, input_slot == DEF_InteractionAction.Slot.SECONDARY),
	)
	if held != null:
		if controller.physical_override:
			return _physical(actor, held, DEF_GrabAction.Kind.THROW)
		# PRIMARY means tool use, independent of physical hand/button mapping.
		return _from_source(actor, held, target, DEF_InteractionAction.Slot.PRIMARY)
	return _from_source(actor, actor, target, input_slot)


## Selects the first rotation-enabled active hand in mapped primary/secondary order.
static func rotation_choice(actor: Entity) -> InteractionActionChoice:
	if InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS:
		return null

	for secondary: bool in [false, true]:
		var held: Entity = S_Grab.held_in_slot(actor, S_Grab.mapped_hand(actor, secondary))
		var result: InteractionActionChoice = _physical(actor, held, DEF_GrabAction.Kind.ROTATE)
		if result != null:
			return result

	return null


## Checks explicit authored reservations for an item input slot.
static func reserves(source: Entity, input_slot: DEF_InteractionAction.Slot) -> bool:
	if not S_Grab.entity_available(source):
		return false

	var actions: C_InteractionActionSet = source.get_component(C_InteractionActionSet)
	if actions == null:
		return false

	if actions.reserved_slots & (1 << input_slot):
		return true

	for action: DEF_InteractionAction in actions.actions:
		if action != null and action.slot == input_slot:
			return true

	return false


## Reports whether this tick consumes camera delta for item rotation.
static func wants_rotation(actor: Entity, controller: C_Controller) -> bool:
	if (
		controller.interact_pressed or controller.use_pressed
		or controller.drop_pressed or controller.drop_long_pressed
	):
		return false
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus == InteractionControlFocus.Priority.CARRY:
		return (
			not controller.action_main_pressed and controller.action_second_held
			and resolve(actor, DEF_InteractionAction.Slot.SECONDARY) != null
		)
	if focus != InteractionControlFocus.Priority.HANDS:
		return false
	if (
		controller.action_main or controller.action_main_pressed
		or controller.action_second_held or controller.action_second_pressed
	):
		return false
	return controller.rotate_held and rotation_choice(actor) != null


## Publishes currently available controls for the read-only interaction HUD.
static func refresh_prompt(actor: Entity) -> void:
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	var lines: PackedStringArray = []
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.TRANSPORT:
		lines.append("[W / S] Вперёд / назад · [A / D] Поворот")
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.DRAWING:
		interactor.prompt_text = "Маркер · кнопка руки + мышь · [E / Esc] Завершить"
		return

	var interact_choice: InteractionActionChoice = resolve(
		actor,
		DEF_InteractionAction.Slot.INTERACT,
	)
	if interact_choice == null and _is_overweight_carry_target(actor, interactor):
		lines.append("Слишком Тяжелое")

	for slot_index: int in BUTTON_LABELS.size():
		var choice: InteractionActionChoice = (
			interact_choice
			if slot_index == DEF_InteractionAction.Slot.INTERACT
			else resolve(actor, slot_index as DEF_InteractionAction.Slot)
		)
		if choice != null:
			lines.append("[%s] %s" % [button_label(slot_index), choice.action.caption])
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.HANDS:
		for secondary: bool in [false, true]:
			if (
				S_Grab.held_in_slot(actor, S_Grab.mapped_hand(actor, secondary)) != null
				and not controller.physical_override
			):
				lines.append(
					"[Alt + %s] Бросить"
					% button_label(
						(
							DEF_InteractionAction.Slot.SECONDARY
							if secondary
							else DEF_InteractionAction.Slot.PRIMARY
						)
					)
				)
		if rotation_choice(actor) != null:
			lines.append("[R + мышь] Вращать")
	if (
		InteractionControlFocus.current(actor) < InteractionControlFocus.Priority.PUSH
		and S_Grab.held_object(actor) != null
	):
		lines.append("[G] Положить · [удерживать G] Контекст")
	if control.context_wheel_requested:
		lines.append("Контекстное колесо — в разработке")
	interactor.prompt_text = "\n".join(lines)


## Reports weight-only Carry rejection for a currently raycast physical body.
static func _is_overweight_carry_target(actor: Entity, interactor: C_Interactor) -> bool:
	if interactor == null or not is_instance_valid(interactor.physics_target):
		return false
	if InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS:
		return false

	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
	if control == null or strength == null:
		return false

	var body: RigidBody3D = interactor.physics_target
	if S_InteractionTargeting.find_physics_target(actor, interactor) != body:
		return false

	var handle: Entity = PhysicsGrabTarget.handle_for(body, false)
	if handle != null:
		var profile: GrabControlProfile = S_Grab.profile_for(handle)
		if profile.allowed_hand_slots != 0:
			return false

	return control.is_too_heavy(body, strength)


## Reads the active InputMap binding for a contextual button.
static func button_label(slot_index: int) -> String:
	for event: InputEvent in InputMap.action_get_events(INPUT_ACTIONS[slot_index]):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			return OS.get_keycode_string(
				key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
			)
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				return "ЛКМ"
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				return "ПКМ"
			return event.as_text()
	return BUTTON_LABELS[slot_index]
#endregion


#region Private helpers
static func _execute_slot(
	actor: Entity,
	input_slot: DEF_InteractionAction.Slot,
	pressed: bool,
	held: bool = false,
) -> bool:
	if not pressed and not held:
		return false
	var choice: InteractionActionChoice = resolve(actor, input_slot)
	if choice != null and (pressed or choice.action.continuous):
		choice.action.execute(actor, choice.source, choice.target)
	# Hand input owns its tick even when use has no valid target.
	return pressed or held


static func _target_action(
	actor: Entity,
	target: Entity,
	input_slot: DEF_InteractionAction.Slot,
) -> InteractionActionChoice:
	if not S_Grab.entity_available(target):
		return _from_source(actor, actor, target, input_slot)
	var action: InteractionActionChoice = _from_source(actor, target, target, input_slot)
	if action == null and input_slot == DEF_InteractionAction.Slot.INTERACT:
		action = _from_source(actor, target, target, DEF_InteractionAction.Slot.USE)
	elif action != null and input_slot == DEF_InteractionAction.Slot.USE:
		var primary: InteractionActionChoice = resolve(actor, DEF_InteractionAction.Slot.INTERACT)
		if primary != null and primary.action == action.action and primary.source == action.source:
			return null
	return action


static func _physical(
	actor: Entity,
	source: Entity,
	kind: DEF_GrabAction.Kind,
) -> InteractionActionChoice:
	if not S_Grab.entity_available(source):
		return null
	var action: DEF_GrabAction = DEF_GrabAction.new()
	action.kind = kind
	action.continuous = kind == DEF_GrabAction.Kind.ROTATE
	match kind:
		DEF_GrabAction.Kind.RELEASE:
			action.caption = "Отпустить"
		DEF_GrabAction.Kind.THROW:
			action.caption = "Бросить"
		DEF_GrabAction.Kind.ROTATE:
			action.caption = "Вращать"
	return _choice(action, source, null) if action.is_available(actor, source, null) else null


static func _from_source(
	actor: Entity,
	source: Entity,
	target: Entity,
	input_slot: DEF_InteractionAction.Slot,
) -> InteractionActionChoice:
	if not S_Grab.entity_available(source):
		return null
	var actions: C_InteractionActionSet = source.get_component(C_InteractionActionSet)
	if actions == null:
		return null
	var best: DEF_InteractionAction = null
	for action: DEF_InteractionAction in actions.actions:
		if (
			action == null or action.slot != input_slot
			or not action.is_available(actor, source, target)
		):
			continue
		if (
			best == null or action.priority > best.priority
			or (
				action.priority == best.priority
				and String(action.action_id) < String(best.action_id)
			)
		):
			best = action
	return _choice(best, source, target) if best != null else null


static func _choice(
	action: DEF_InteractionAction,
	source: Entity,
	target: Entity,
) -> InteractionActionChoice:
	var choice: InteractionActionChoice = InteractionActionChoice.new()
	choice.action = action
	choice.source = source
	choice.target = target
	return choice
#endregion
