@tool
extends Entity
## Forwards the cart's CharacterBody physics step to its dedicated transport solver.
class_name E_TransportCart


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		S_CartTransport.step(self, delta)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		S_CartTransport.end(self)
