extends RefCounted
## Направляет ввод и подсказки через арбитраж управления и сопоставление физических рук.
class_name InteractionActionResolver

const INPUT_ACTIONS: Array[StringName] = [
	&"interact",
	&"use",
	&"action_primary",
	&"action_secondary",
]


#region Действия и подсказки
## Выбирает доступное действие канала без исполнения; excluded_capture исключает собственный токен сеанса.
static func resolve(
	actor: Entity,
	input_slot: DEF_InteractionAction.Slot,
	excluded_capture: int = 0,
) -> InteractionActionChoice:
	if not GrabQueries.holder_available(actor):
		return null

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	if interactor == null or controller == null:
		return null

	var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor, excluded_capture)
	if focus >= InteractionControlFocus.Priority.PROLONGED:
		return null

	var target: Entity = interactor.target if is_instance_valid(interactor.target) else null
	if target != null and InteractionTargetingGeometry.find_target(actor, interactor) != target:
		target = null
	var physics_target: RigidBody3D = (
		interactor.physics_target if is_instance_valid(interactor.physics_target) else null
	)
	if (
		physics_target != null
		and InteractionTargetingGeometry.find_physics_target(actor, interactor) != physics_target
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
			var cart: Entity = PushService.pushed_object(actor)
			if cart == null:
				return null

			var stop: DEF_PushAction = DEF_PushAction.new()
			stop.end_push = true
			stop.caption = "Отпустить тележку"
			return _choice(stop, cart, target)
		if input_slot == DEF_InteractionAction.Slot.USE:
			return _target_action(actor, target, input_slot)
		return null

	var carry: Entity = GrabQueries.held_in_slot(actor, C_Grabbable.HoldSlot.CARRY)
	if focus == InteractionControlFocus.Priority.CARRY:
		if input_slot == DEF_InteractionAction.Slot.INTERACT:
			var placement: InteractionActionChoice = _from_source(actor, target, target, input_slot)
			if placement != null and placement.action is DEF_CarryPlacementAction:
				return placement
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
			and GrabQueries.physical_body(target) == physics_target
		)
		# Авторское действие имеет приоритет, если сущность не определила собственное поведение Grab.
		if target_action != null and not authored_grab:
			return target_action

		var selected: int = GrabQueries.pickup_slot_for_body(
			actor,
			physics_target,
			input_slot == DEF_InteractionAction.Slot.USE,
		)
		var replace: bool = selected != C_Grabbable.HoldSlot.CARRY
		var handle: Entity = PhysicsGrabTarget.handle_for(physics_target, false)
		if GrabService.can_pickup_body(actor, physics_target, selected, replace, handle):
			var pickup: DEF_GrabAction = DEF_GrabAction.new()
			pickup.kind = DEF_GrabAction.Kind.PICKUP
			pickup.hold_slot = selected
			pickup.replace_occupant = replace
			pickup.physical_body = physics_target
			pickup.caption = "Заменить" if GrabQueries.held_in_slot(actor, selected) != null else "Взять"

			if selected != C_Grabbable.HoldSlot.CARRY:
				var right_hand: bool = selected == C_Grabbable.HoldSlot.RIGHT_HAND
				pickup.caption += " · правая рука" if right_hand else " · левая рука"

			return _choice(pickup, handle, target)
		return target_action


	var held: Entity = GrabQueries.held_in_slot(
		actor,
		GrabQueries.mapped_hand(actor, input_slot == DEF_InteractionAction.Slot.SECONDARY),
	)
	if held != null:
		if controller.physical_override:
			return _physical(actor, held, DEF_GrabAction.Kind.THROW)
		# PRIMARY означает применение инструмента независимо от сопоставления физической руки кнопке.
		return _from_source(actor, held, target, DEF_InteractionAction.Slot.PRIMARY)
	return _from_source(actor, actor, target, input_slot)


## Выбирает первую руку с доступным вращением в порядке основного и дополнительного ввода.
static func rotation_choice(actor: Entity) -> InteractionActionChoice:
	if InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.HANDS:
		return null

	for secondary: bool in [false, true]:
		var held: Entity = GrabQueries.held_in_slot(actor, GrabQueries.mapped_hand(actor, secondary))
		var result: InteractionActionChoice = _physical(actor, held, DEF_GrabAction.Kind.ROTATE)
		if result != null:
			return result

	return null


## Проверяет авторский резерв предмета для канала ввода.
static func reserves(source: Entity, input_slot: DEF_InteractionAction.Slot) -> bool:
	if not GrabQueries.entity_available(source):
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


## Проверяет, используется ли поворот камеры этого снимка для вращения предмета.
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


## Обновляет доступные команды для чтения HUD взаимодействий.
static func refresh_prompt(actor: Entity) -> void:
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var lines: PackedStringArray = []
	var prolonged: Relationship = ProlongedInteractionService.session(actor)
	if prolonged != null and InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.PROLONGED:
		var data: R_ProlongedOn = prolonged.relation as R_ProlongedOn
		interactor.prompt_text = "[удерживать %s] %s" % [button_label(data.input_slot), data.action.caption]
		return
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.TRANSPORT:
		lines.append("%s / %s Вперёд / назад · %s / %s Поворот" % [InputPromptService.token(&"forward"), InputPromptService.token(&"back"), InputPromptService.token(&"left"), InputPromptService.token(&"right")])
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.DRAWING:
		interactor.prompt_text = "Маркер · кнопка руки + мышь · %s / %s Завершить" % [InputPromptService.token(&"interact"), InputPromptService.token(&"menu")]
		return

	var interact_choice: InteractionActionChoice = resolve(
		actor,
		DEF_InteractionAction.Slot.INTERACT,
	)
	if interact_choice == null and _is_overweight_carry_target(actor, interactor):
		lines.append("Слишком Тяжелое")

	for slot_index: int in INPUT_ACTIONS.size():
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
				GrabQueries.held_in_slot(actor, GrabQueries.mapped_hand(actor, secondary)) != null
				and not controller.physical_override
			):
				lines.append(
					"%s + %s Бросить"
					% [InputPromptService.token(&"physical_override"), button_label(
						(
							DEF_InteractionAction.Slot.SECONDARY
							if secondary
							else DEF_InteractionAction.Slot.PRIMARY
						)
					)]
				)
		if rotation_choice(actor) != null:
			lines.append("%s + мышь Вращать" % InputPromptService.token(&"rotate_held"))
	if (
		InteractionControlFocus.current(actor) < InteractionControlFocus.Priority.PUSH
		and GrabQueries.held_object(actor) != null
	):
		lines.append("%s Положить" % InputPromptService.token(&"drop"))

	var denial: String = _access_denial(actor, interactor)
	if not denial.is_empty():
		lines.append(denial)
	interactor.prompt_text = "\n".join(lines)


static func _access_denial(actor: Entity, interactor: C_Interactor) -> String:
	if InteractionControlFocus.current(actor) > InteractionControlFocus.Priority.CARRY:
		return ""

	var target: Entity = interactor.target if is_instance_valid(interactor.target) else null
	if target == null or InteractionTargetingGeometry.find_target(actor, interactor) != target:
		return ""

	var lock: C_Openable = target.get_component(C_Openable) as C_Openable
	if lock == null or not lock.locked:
		return ""

	var result: AccessResult = ItemAccessService.evaluate(actor, lock.access)
	match result.outcome:
		AccessResult.Outcome.ITEM_REQUIRED:
			return "Заперто · нужен подходящий ключ или предмет"

		AccessResult.Outcome.CONSUMPTION_UNAVAILABLE:
			return "Заперто · нужен расходуемый предмет"

		AccessResult.Outcome.INVALID_REQUIREMENT:
			return "Замок недоступен"
	return ""


## Проверяет отказ Carry именно по массе текущего физического тела под лучом.
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
	if InteractionTargetingGeometry.find_physics_target(actor, interactor) != body:
		return false

	var handle: Entity = PhysicsGrabTarget.handle_for(body, false)
	if handle != null:
		var profile: GrabControlProfile = GrabQueries.profile_for(handle)
		if profile.allowed_hand_slots != 0:
			return false

	return GrabQueries.is_too_heavy(body, strength)


## Семантический token; UI подставляет Texture2D фактического назначения.
static func button_label(slot_index: int) -> String:
	return InputPromptService.token(INPUT_ACTIONS[slot_index])
#endregion


#region Исполнение и выбор источника
## Resolves and executes one explicit channel request; scheduled input arbitration belongs to S_InteractionInput.
static func execute_slot(
	actor: Entity,
	input_slot: DEF_InteractionAction.Slot,
	pressed: bool,
	held: bool = false,
) -> bool:
	if not pressed and not held:
		return false

	var choice: InteractionActionChoice = resolve(actor, input_slot)
	if choice != null and (pressed or choice.action.continuous):
		if choice.action.timing != null:
			if pressed:
				ProlongedInteractionService.begin(actor, choice, input_slot)
		else:
			choice.action.execute(actor, choice.source, choice.target)
	# Ввод руки занимает свой снимок даже без допустимой цели применения.
	return pressed or held


static func _target_action(
	actor: Entity,
	target: Entity,
	input_slot: DEF_InteractionAction.Slot,
) -> InteractionActionChoice:
	if not GrabQueries.entity_available(target):
		return _from_source(actor, actor, target, input_slot)

	var action: InteractionActionChoice = _from_source(actor, target, target, input_slot)
	if action == null and input_slot == DEF_InteractionAction.Slot.INTERACT:
		action = _from_source(actor, target, target, DEF_InteractionAction.Slot.USE)
		# Некоторые USE-действия доступны только по F и не подставляются в свободный канал E.
		if (
			action != null
			and (
				action.action is DEF_PhysicalSlotAction
				or not action.action.allow_interact_fallback
			)
		):
			return null
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
	if not GrabQueries.entity_available(source):
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
	if not GrabQueries.entity_available(source):
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
