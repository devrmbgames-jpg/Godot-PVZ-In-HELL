extends System
## Преобразует фронт прыжка на опоре в одноразовый импульс; тело исполняет его отдельно.
class_name S_Jump


## Выбирает персонажей с данными прыжка, управления и движения.
func query() -> QueryBuilder:
	return q.with_all([C_Jump, C_Controller, C_Motion]).iterate([C_Jump, C_Controller, C_Motion])


## После фронта ввода на опоре ставит импульс в Н·с; удержание кнопки не повторяет прыжок.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var jumps: Array = components[0]
	var controllers: Array = components[1]
	var motions: Array = components[2]
	for entity_index: int in entities.size():
		var jump: C_Jump = jumps[entity_index]
		var controller: C_Controller = controllers[entity_index]
		var motion: C_Motion = motions[entity_index]
		var just_pressed: bool = controller.action_jump and not jump.was_pressed
		jump.was_pressed = controller.action_jump
		jump.active = false

		if not just_pressed or not motion.control_enabled or not motion.is_on_floor:
			continue
		if jump.jump_force <= 0.0:
			continue

		# Физический callback тела потребляет импульс вместе с другими игровыми импульсами.
		motion.pending_impulse += Vector3.UP * jump.jump_force
		motion.is_on_floor = false
		jump.active = true
