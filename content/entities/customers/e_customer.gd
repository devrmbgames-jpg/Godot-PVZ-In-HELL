@tool
extends Entity
## Thin engine glue: CharacterBody3D is the only owner of physical movement.
class_name E_Customer


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	CustomerMotionService.step(self, delta)


func show_message(message: String) -> void:
	var label: Label3D = get_node_or_null("Message") as Label3D
	if label != null:
		label.text = message
