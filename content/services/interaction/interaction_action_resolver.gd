extends RefCounted
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
static func handle_input(actor: Entity) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	if controller.input_tick > 0 and interactor.last_action_tick == controller.input_tick:
		return
	interactor.last_action_tick = controller.input_tick
	control.rotation_active = false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PUSH:
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
		_execute_slot(actor, InteractionAction.Slot.INTERACT, true)
	elif controller.use_pressed:
		_execute_slot(actor, InteractionAction.Slot.USE, true)
	else:
		# Snapshot focus: releasing Carry cannot route this same tick into hands.
		var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
		var primary_consumed: bool = _execute_slot(
			actor,
			InteractionAction.Slot.PRIMARY,
			controller.action_main_pressed,
			controller.action_main,
		)
		if focus == InteractionControlFocus.current(actor):
			var secondary_consumed: bool = _execute_slot(
				actor,
				InteractionAction.Slot.SECONDARY,
				controller.action_second_pressed,
				controller.action_second_held,
			)
			if not primary_consumed and not secondary_consumed and controller.rotate_held:
				var rotation: InteractionActionChoice = rotation_choice(actor)
				if rotation != null:
					rotation.action.execute(actor, rotation.source, rotation.target)
	refresh_prompt(actor)


static func resolve(actor: Entity, input_slot: InteractionAction.Slot) -> InteractionActionChoice:
	if not S_Grab.holder_available(actor):
		return null
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	if interactor == null or controller == null:
		return null
	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
	if focus >= InteractionControlFocus.Priority.PUSH:
		return null
	var target: Entity = interactor.target if is_instance_valid(interactor.target) else null
	if target != null and S_InteractionTargeting.find_target(actor, interactor) != target:
		target = null
	var carry: Entity = S_Grab.held_in_slot(actor, C_Grabbable.HoldSlot.CARRY)
	if focus == InteractionControlFocus.Priority.CARRY:
		if input_slot == InteractionAction.Slot.INTERACT:
			return _physical(actor, carry, GrabAction.Kind.RELEASE)
		if input_slot == InteractionAction.Slot.PRIMARY:
			return _physical(actor, carry, GrabAction.Kind.THROW)
		if input_slot == InteractionAction.Slot.SECONDARY:
			return _physical(actor, carry, GrabAction.Kind.ROTATE)
		return _target_action(actor, target, input_slot)
	if input_slot == InteractionAction.Slot.INTERACT or input_slot == InteractionAction.Slot.USE:
		var selected: int = S_Grab.pickup_slot(
			actor,
			target,
			input_slot == InteractionAction.Slot.USE,
		)
		var replace: bool = selected != C_Grabbable.HoldSlot.CARRY
		if S_Grab.can_pickup(actor, target, selected, replace):
			var pickup: GrabAction = GrabAction.new()
			pickup.kind = GrabAction.Kind.PICKUP
			pickup.hold_slot = selected
			pickup.replace_occupant = replace
			pickup.caption = "Заменить" if S_Grab.held_in_slot(actor, selected) != null else "Взять"
			if selected != C_Grabbable.HoldSlot.CARRY:
				var right_hand: bool = selected == C_Grabbable.HoldSlot.RIGHT_HAND
				pickup.caption += " · правая рука" if right_hand else " · левая рука"
			return _choice(pickup, target, target)
		return _target_action(actor, target, input_slot)
	var held: Entity = S_Grab.held_in_slot(
		actor,
		S_Grab.mapped_hand(actor, input_slot == InteractionAction.Slot.SECONDARY),
	)
	if held != null:
		if controller.physical_override:
			return _physical(actor, held, GrabAction.Kind.THROW)
		# PRIMARY means tool use, independent of physical hand/button mapping.
		return _from_source(actor, held, target, InteractionAction.Slot.PRIMARY)
	return _from_source(actor, actor, target, input_slot)


static func rotation_choice(actor: Entity) -> InteractionActionChoice:
	if InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS:
		return null
	for secondary: bool in [false, true]:
		var held: Entity = S_Grab.held_in_slot(actor, S_Grab.mapped_hand(actor, secondary))
		var result: InteractionActionChoice = _physical(actor, held, GrabAction.Kind.ROTATE)
		if result != null:
			return result
	return null


static func reserves(source: Entity, input_slot: InteractionAction.Slot) -> bool:
	if not S_Grab.entity_available(source):
		return false
	var actions: C_InteractionActionSet = source.get_component(C_InteractionActionSet)
	if actions == null:
		return false
	if actions.reserved_slots & (1 << input_slot):
		return true
	for action: InteractionAction in actions.actions:
		if action != null and action.slot == input_slot:
			return true
	return false


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
			and resolve(actor, InteractionAction.Slot.SECONDARY) != null
		)
	if focus != InteractionControlFocus.Priority.HANDS:
		return false
	if (
		controller.action_main or controller.action_main_pressed
		or controller.action_second_held or controller.action_second_pressed
	):
		return false
	return controller.rotate_held and rotation_choice(actor) != null


static func refresh_prompt(actor: Entity) -> void:
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	var lines: PackedStringArray = []
	for slot_index: int in BUTTON_LABELS.size():
		var choice: InteractionActionChoice = resolve(actor, slot_index as InteractionAction.Slot)
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
							InteractionAction.Slot.SECONDARY
							if secondary
							else InteractionAction.Slot.PRIMARY
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
	input_slot: InteractionAction.Slot,
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
	input_slot: InteractionAction.Slot,
) -> InteractionActionChoice:
	if not S_Grab.entity_available(target):
		return _from_source(actor, actor, target, input_slot)
	var action: InteractionActionChoice = _from_source(actor, target, target, input_slot)
	if action == null and input_slot == InteractionAction.Slot.INTERACT:
		action = _from_source(actor, target, target, InteractionAction.Slot.USE)
	elif action != null and input_slot == InteractionAction.Slot.USE:
		var primary: InteractionActionChoice = resolve(actor, InteractionAction.Slot.INTERACT)
		if primary != null and primary.action == action.action and primary.source == action.source:
			return null
	return action


static func _physical(actor: Entity, source: Entity, kind: GrabAction.Kind) -> InteractionActionChoice:
	if not S_Grab.entity_available(source):
		return null
	var action: GrabAction = GrabAction.new()
	action.kind = kind
	action.continuous = kind == GrabAction.Kind.ROTATE
	match kind:
		GrabAction.Kind.RELEASE:
			action.caption = "Отпустить"
		GrabAction.Kind.THROW:
			action.caption = "Бросить"
		GrabAction.Kind.ROTATE:
			action.caption = "Вращать"
	return _choice(action, source, null) if action.is_available(actor, source, null) else null


static func _from_source(
	actor: Entity,
	source: Entity,
	target: Entity,
	input_slot: InteractionAction.Slot,
) -> InteractionActionChoice:
	if not S_Grab.entity_available(source):
		return null
	var actions: C_InteractionActionSet = source.get_component(C_InteractionActionSet)
	if actions == null:
		return null
	var best: InteractionAction = null
	for action: InteractionAction in actions.actions:
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


static func _choice(action: InteractionAction, source: Entity, target: Entity) -> InteractionActionChoice:
	var choice: InteractionActionChoice = InteractionActionChoice.new()
	choice.action = action
	choice.source = source
	choice.target = target
	return choice
#endregion
