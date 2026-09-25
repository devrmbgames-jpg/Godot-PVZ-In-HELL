@tool
extends Entity
## Owns the CharacterBody cart callback boundary.
class_name E_TransportCart

@onready var cargo_area: Area3D = $CargoArea


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		CartDriveSolver.step(self, delta)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		CartCargoService.release_all(self)
		CartTransportService.end(self)
