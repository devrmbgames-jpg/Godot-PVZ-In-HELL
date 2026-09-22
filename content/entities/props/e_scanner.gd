@tool
extends E_Grabbable
class_name E_Scanner

signal scan_feedback(result: ScanResult)


func define_components() -> Array:
	var actions: C_InteractionActions = C_InteractionActions.new()
	var scan: ScanAction = ScanAction.new()
	scan.action_id = &"scan_package"
	scan.slot = InteractionAction.Slot.PRIMARY
	scan.caption = "Сканировать"
	actions.actions = [scan]
	actions.reserved_slots = 1 << InteractionAction.Slot.PRIMARY
	var carry: C_Grabbable = C_Grabbable.new()
	carry.hold_slot = C_Grabbable.HoldSlot.RIGHT_HAND
	return [C_Scanner.new(), C_Interactable.new(), carry, actions]
