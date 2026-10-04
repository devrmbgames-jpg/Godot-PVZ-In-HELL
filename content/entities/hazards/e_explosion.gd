@tool
extends E_Hazard
## Сцена автономного взрыва и его представление без собственной арифметики HP/импульса.
class_name E_Explosion

@onready var _visual: MeshInstance3D = $Visual
@onready var _spatial: Node3D = self as Node as Node3D


## Возвращает mesh представления взрыва.
func get_visual() -> MeshInstance3D:
	return _visual


## Возвращает пространственный корень для мирового центра взрыва.
func get_spatial() -> Node3D:
	return _spatial
