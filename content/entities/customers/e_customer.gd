@tool
extends E_NpcCharacter
## Customer presentation over the shared rigid character physics callback.
class_name E_Customer


func show_message(message: String) -> void:
	var label: Label3D = get_node_or_null("Message") as Label3D
	if label != null:
		label.text = message
