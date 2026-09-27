@tool
extends Entity
## Owns the CharacterBody cart callback boundary.
class_name E_TransportCart

@onready var _cargo_area: Area3D = $CargoArea


func get_cargo_area() -> Area3D:
	return _cargo_area


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		CartDriveSolver.step(self, delta)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		CartCargoService.release_all(self)
		CartTransportService.end(self)
