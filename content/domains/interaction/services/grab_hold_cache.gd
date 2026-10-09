extends RefCounted
## Пишет производный slot cache и очищает Carry modifiers; владение остаётся в R_HeldBy.
class_name GrabHoldCache

#region Derived slot cache
## Очищает производный кеш слота и модификаторы Carry, не создавая владение.
static func reset_holder(holder: Entity, slot_index: int = C_Grabbable.HoldSlot.CARRY) -> void:
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control != null:
		var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
		if interactor != null and interactor.target == cached(control, slot_index):
			interactor.target = null
		set_cached(control, slot_index, null)
		control.rotation_active = false

	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if load_state != null and slot_index == C_Grabbable.HoldSlot.CARRY:
		load_state.active = false
		load_state.mass_kg = 0.0


## Читает производный указатель выбранного слота; живую связь проверяет GrabQueries.
static func cached(control: C_GrabControl, slot_index: int) -> Entity:
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			return control.held_carry

		C_Grabbable.HoldSlot.RIGHT_HAND:
			return control.held_right

		C_Grabbable.HoldSlot.LEFT_HAND:
			return control.held_left
	return null


## Записывает производный указатель после принятия или очистки живой связи.
static func set_cached(control: C_GrabControl, slot_index: int, held: Entity) -> void:
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			control.held_carry = held
		C_Grabbable.HoldSlot.RIGHT_HAND:
			control.held_right = held
		C_Grabbable.HoldSlot.LEFT_HAND:
			control.held_left = held
#endregion
