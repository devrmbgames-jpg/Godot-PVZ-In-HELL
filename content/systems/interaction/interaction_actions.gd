extends RefCounted
class_name InteractionActions

const BUTTON_LABELS: Array[String] = ["E", "F", "ЛКМ", "ПКМ"]
const INPUT_ACTIONS: Array[StringName] = [
	&"interact",
	&"use",
	&"action_primary",
	&"action_secondary",
]
static var _grab_actions: Array[GrabAction] = []


#region Public API
## Called at the command boundary, after invalid grips have been released.
static func handle_input(actor: Entity) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	if controller.input_tick > 0 and interactor.last_action_tick == controller.input_tick:
		return
	interactor.last_action_tick = controller.input_tick
	control.rotation_active = false
	# E owns this tick when pressed: dropping a tool cannot also trigger an attack.
	if controller.interact_pressed:
		_execute_slot(actor, InteractionAction.Slot.INTERACT)
	else:
		if controller.use_pressed:
			_execute_slot(actor, InteractionAction.Slot.USE)
		if controller.action_main_pressed:
			_execute_slot(actor, InteractionAction.Slot.PRIMARY)
		if controller.action_second_held:
			var secondary: InteractionChoice = resolve(actor, InteractionAction.Slot.SECONDARY)
			if (
				secondary != null
				and (secondary.action.continuous or controller.action_second_pressed)
			):
				secondary.action.execute(actor, secondary.source, secondary.target)
	refresh_prompt(actor)


## Scope order is held tool -> held physical object -> aimed target -> actor fallback.
## Within a scope: higher priority wins; equal priority uses lexical action_id.
static func resolve(actor: Entity, input_slot: InteractionAction.Slot) -> InteractionChoice:
	if not S_Grab.holder_available(actor):
		return null
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	if interactor == null or controller == null:
		return null
	var target: Entity = interactor.target if is_instance_valid(interactor.target) else null
	# Targeting owns selection/highlights; command validation never overwrites its snapshot.
	if target != null and S_InteractionTargeting.find_target(actor, interactor) != target:
		target = null
	var held: Entity = S_Grab.held_object(actor)
	if held != null:
		if not controller.physical_override:
			var tool_choice: InteractionChoice = _from_source(actor, held, target, input_slot)
			if tool_choice != null:
				return tool_choice
			if reserves(held, input_slot):
				return null
		var held_choice: InteractionChoice = _grab_choice(actor, held, target, input_slot)
		if held_choice != null:
			return held_choice
	if S_Grab.entity_available(target):
		# E attempts pickup first; an ungrabbable object falls through to use.
		var pickup: InteractionChoice = _grab_choice(actor, target, target, input_slot)
		if pickup != null:
			return pickup
		var target_choice: InteractionChoice = _from_source(actor, target, target, input_slot)
		if target_choice != null:
			if input_slot == InteractionAction.Slot.USE:
				var primary_choice: InteractionChoice = resolve(
					actor,
					InteractionAction.Slot.INTERACT,
				)
				if (
					primary_choice != null and primary_choice.action == target_choice.action
					and primary_choice.source == target_choice.source
				):
					return null
			return target_choice
		if input_slot == InteractionAction.Slot.INTERACT:
			var use_choice: InteractionChoice = _from_source(
				actor,
				target,
				target,
				InteractionAction.Slot.USE,
			)
			if use_choice != null:
				return use_choice
	return _from_source(actor, actor, target, input_slot)


static func reserves(source: Entity, input_slot: InteractionAction.Slot) -> bool:
	if not S_Grab.entity_available(source):
		return false
	var actions: C_InteractionActions = source.get_component(C_InteractionActions)
	if actions == null:
		return false
	if actions.reserved_slots & (1 << input_slot):
		return true
	for action: InteractionAction in actions.actions:
		if action != null and action.slot == input_slot:
			return true
	return false


static func wants_rotation(actor: Entity, controller: C_Controller) -> bool:
	var held: Entity = S_Grab.held_object(actor)
	var config: C_Grabbable = held.get_component(C_Grabbable) as C_Grabbable if held != null else null
	return (
		config != null and config.manual_rotation_enabled and controller.action_second_held
		and (controller.physical_override or not reserves(held, InteractionAction.Slot.SECONDARY))
	)


static func refresh_prompt(actor: Entity) -> void:
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var lines: PackedStringArray = []
	var primary: InteractionChoice = resolve(actor, InteractionAction.Slot.INTERACT)
	for slot_index: int in BUTTON_LABELS.size():
		var choice: InteractionChoice = resolve(actor, slot_index as InteractionAction.Slot)
		if choice != null:
			if (
				slot_index == InteractionAction.Slot.USE and primary != null
				and (
					(choice.action == primary.action and choice.source == primary.source)
					or button_label(InteractionAction.Slot.USE)
					== button_label(InteractionAction.Slot.INTERACT)
				)
			):
				continue
			lines.append("[%s] %s" % [button_label(slot_index), choice.action.caption])
	var held: Entity = S_Grab.held_object(actor)
	if held != null and not controller.physical_override:
		if reserves(held, InteractionAction.Slot.PRIMARY):
			lines.append("[Alt + ЛКМ] Бросить")
		if reserves(held, InteractionAction.Slot.SECONDARY):
			lines.append("[Alt + ПКМ] Вращать")
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
static func _execute_slot(actor: Entity, input_slot: InteractionAction.Slot) -> void:
	var choice: InteractionChoice = resolve(actor, input_slot)
	if choice != null:
		choice.action.execute(actor, choice.source, choice.target)


static func _from_source(
	actor: Entity,
	source: Entity,
	target: Entity,
	input_slot: InteractionAction.Slot,
) -> InteractionChoice:
	if not S_Grab.entity_available(source):
		return null
	var actions: C_InteractionActions = source.get_component(C_InteractionActions)
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


static func _grab_choice(
	actor: Entity,
	source: Entity,
	target: Entity,
	input_slot: InteractionAction.Slot,
) -> InteractionChoice:
	if _grab_actions.is_empty():
		var captions: Array[String] = ["Взять", "Отпустить", "Бросить", "Вращать"]
		var slots: Array[int] = [0, 0, 2, 3]
		for kind_index: int in captions.size():
			var action: GrabAction = GrabAction.new()
			action.kind = kind_index as GrabAction.Kind
			action.slot = slots[kind_index] as InteractionAction.Slot
			action.caption = captions[kind_index]
			action.continuous = action.kind == GrabAction.Kind.ROTATE
			_grab_actions.append(action)
	for action: GrabAction in _grab_actions:
		if action.slot == input_slot and action.is_available(actor, source, target):
			return _choice(action, source, target)
	return null


static func _choice(action: InteractionAction, source: Entity, target: Entity) -> InteractionChoice:
	var choice: InteractionChoice = InteractionChoice.new()
	choice.action = action
	choice.source = source
	choice.target = target
	return choice
#endregion
