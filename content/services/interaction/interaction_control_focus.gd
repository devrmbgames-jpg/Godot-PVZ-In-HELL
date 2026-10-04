extends RefCounted
## Разрешает приоритет независимых вложенных захватов ввода, не меняя владение предметами.
class_name InteractionControlFocus

enum Priority {
	HANDS,
	CARRY,
	PUSH,
	TRANSPORT,
	PROLONGED,
	DRAWING,
	MODAL,
}


#region Независимые токены управления
## Выдаёт отдельный токен даже для повторного захвата тем же владельцем; ноль означает отказ.
static func acquire(actor: Entity, owner: Object, priority: Priority) -> int:
	var control: C_GrabControl = _control(actor)
	if control != null and is_instance_valid(owner):
		var capture: InteractionControlCapture = InteractionControlCapture.new()
		capture.owner = weakref(owner)
		capture.priority = priority

		var token: int = capture.get_instance_id()
		control.captures[token] = capture
		control.rotation_active = false
		return token

	return 0


## Освобождает только указанный токен, сохраняя приоритеты остальных владельцев.
static func release(actor: Entity, token: int) -> void:
	var control: C_GrabControl = _control(actor)
	if control != null:
		control.captures.erase(token)


## Возвращает высший живой приоритет, исключая excluded_token и очищая исчезнувших владельцев.
static func current(actor: Entity, excluded_token: int = 0) -> Priority:
	var control: C_GrabControl = _control(actor)
	var priority: int = Priority.HANDS

	if control != null:
		for token: int in control.captures.keys():
			if token == excluded_token:
				continue

			var capture: InteractionControlCapture = control.captures[token]
			if capture.owner.get_ref() == null:
				control.captures.erase(token)
			else:
				priority = maxi(priority, capture.priority)

	return priority as Priority


#endregion

#region Данные актора
static func _control(actor: Entity) -> C_GrabControl:
	return actor.get_component(C_GrabControl) as C_GrabControl if is_instance_valid(actor) else null

#endregion
