@tool
extends Entity
## Владеет границей физического шага транспортной тележки CharacterBody3D и освобождением участия.
class_name E_TransportCart

@onready var _cargo_area: Area3D = $CargoArea


#region Физический цикл и освобождение
## Возвращает авторскую Area3D CargoArea для физических кандидатов груза.
func get_cargo_area() -> Area3D:
	return _cargo_area


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		CartDriveSolver.step(self, delta)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		CartCargoService.release_all(self)
		CartTransportService.end(self)

#endregion
