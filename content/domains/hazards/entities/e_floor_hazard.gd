@tool
extends E_Hazard
## Представление плоской опасности: размеры и цвет подготовки/активного состояния.
class_name E_FloorHazard

@onready var _visual: MeshInstance3D = $Visual


## Создаёт плоскость авторского размера и показывает подготовку.
func configure(profile: DEF_FloorHazard) -> void:
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = profile.size
	_visual.mesh = mesh
	set_danger_active(false)


## Выбирает цвет подготовки/опасности, не применяя урон.
func set_danger_active(active: bool) -> void:
	var profile: DEF_FloorHazard = definition as DEF_FloorHazard
	var material: StandardMaterial3D = _visual.material_override as StandardMaterial3D
	material.albedo_color = profile.active_color if active else profile.preparation_color
