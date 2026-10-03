@tool
extends E_NpcCharacter
## Customer presentation over the shared rigid character physics callback.
class_name E_Customer

@export var inspection_animation: StringName = &""
@export var receiving_animation: StringName = &""
@export var dialogue_animation: StringName = &""


func _stationary_animation() -> StringName:
	var agent: C_CustomerAgent = get_component(C_CustomerAgent) as C_CustomerAgent
	var candidate: StringName = &""
	if agent != null:
		match agent.phase:
			C_CustomerAgent.Phase.INSPECTING, C_CustomerAgent.Phase.OPTIONAL_FITTING: candidate = inspection_animation
			C_CustomerAgent.Phase.RECEIVING: candidate = receiving_animation
			C_CustomerAgent.Phase.DIALOGUE: candidate = dialogue_animation
	return candidate if animation_player != null and animation_player.has_animation(candidate) else idle_animation


func show_message(message: String) -> void:
	var label: Label3D = get_node_or_null("Message") as Label3D
	if label != null:
		label.text = message
