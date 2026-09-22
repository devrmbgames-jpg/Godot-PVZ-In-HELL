@tool
extends Entity
class_name E_DayStation

@export var sleep_station: bool = false


func _ready() -> void:
	var sign_label: Label3D = get_node_or_null("Sign") as Label3D
	if sign_label != null:
		sign_label.text = "ОТДЫХ\nСон до утра" if sleep_station else "СМЕНА\nНачать / завершить"


func define_components() -> Array:
	var actions: C_InteractionActions = C_InteractionActions.new()
	if sleep_station:
		actions.actions.append(_action(DayTransitionRequest.Kind.SLEEP, "Лечь спать"))
	else:
		actions.actions.append(_action(DayTransitionRequest.Kind.START_SHIFT, "Начать смену"))
		actions.actions.append(_action(DayTransitionRequest.Kind.FINISH_SHIFT, "Завершить смену"))
	return [C_Interactable.new(), actions]


func _action(kind: DayTransitionRequest.Kind, label: String) -> DayPhaseAction:
	var action: DayPhaseAction = DayPhaseAction.new()
	action.transition = kind
	action.slot = InteractionAction.Slot.USE
	action.action_id = StringName("phase_%d" % kind)
	action.caption = label
	return action
