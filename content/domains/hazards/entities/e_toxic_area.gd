@tool
extends E_Hazard
## Тонкий доступ к Area3D объёмной опасности; время и здоровье принадлежат игровому контуру.
class_name E_ToxicArea

@onready var _area: Area3D = $Area
@onready var _shape: CollisionShape3D = $Area/Shape
@onready var _visual: MeshInstance3D = $Visual


## Возвращает авторский Area3D для получения физических кандидатов.
func get_area() -> Area3D:
	return _area


## Возвращает форму объёма для настройки геометрии.
func get_shape() -> CollisionShape3D:
	return _shape


## Возвращает mesh представления объёма.
func get_visual() -> MeshInstance3D:
	return _visual
