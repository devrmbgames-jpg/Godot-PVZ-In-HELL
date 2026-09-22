extends Control
## Displays the active marker's virtual pointer without consuming input.
class_name MarkerPointer

const POINTER_RADIUS: float = 4.0

var _pointer: Vector2 = Vector2.ZERO
var _active: bool = false


func _process(_delta: float) -> void:
	_active = false
	if is_instance_valid(ECS.world):
		for tool: Entity in ECS.world.query.with_all([C_Marker]).execute():
			var marker: C_Marker = tool.get_component(C_Marker) as C_Marker
			if marker.capture_token != 0:
				_active = true
				_pointer = marker.pointer
				break

	queue_redraw()


func _draw() -> void:
	if _active:
		draw_circle(_pointer, POINTER_RADIUS + 1.0, Color.BLACK)
		draw_circle(_pointer, POINTER_RADIUS, Color(1.0, 0.75, 0.15))
