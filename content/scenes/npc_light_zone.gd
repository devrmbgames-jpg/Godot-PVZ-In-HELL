extends Area3D
## Авторская зона игрового света; переносной свет игрока использует такой же Area3D.
class_name NpcLightZone

## Освещённость внутри зоны, нормированная от 0 до 1.
@export_range(0.0, 1.0) var exposure: float = 1.0
## Независимый переключатель источника для будущего переносного света.
@export var enabled: bool = true
## Включить у переносного света; неподвижная зона сохраняет геометрию один раз.
@export var moving_source: bool = false
## Необязательный ID выключателя; пустое значение делает зону независимой.
@export var circuit_id: StringName = &""
## Необязательные часы существующего визуального света для согласованного мерцания.
@export var flicker_view_path: NodePath = NodePath("")

@onready var _volume: CollisionShape3D = $CollisionShape3D
@onready var _flicker_view: CircuitLightView = get_node_or_null(flicker_view_path) as CircuitLightView if not flicker_view_path.is_empty() else null

var _inverse_transform: Transform3D = Transform3D.IDENTITY
var _box_bounds: AABB = AABB()
var _sphere_radius_squared: float = 0.0
var _valid_volume: bool = false

#region Регистрация
func _enter_tree() -> void:
	NpcLightingService.register_zone(self)

func _ready() -> void:
	_capture_volume()

func _exit_tree() -> void:
	NpcLightingService.unregister_zone(self)
#endregion

#region Проверка зоны
## Проверяет одну авторскую коробчатую или сферическую зону без лучей и поиска ламп.
func contains_point(world_position: Vector3) -> bool:
	if not enabled or not is_node_ready() or _volume.disabled:
		return false
	if moving_source:
		_capture_volume()
	if not _valid_volume:
		return false

	var point: Vector3 = _inverse_transform * world_position
	return point.length_squared() <= _sphere_radius_squared if _sphere_radius_squared > 0.0 else _box_bounds.has_point(point)

func _capture_volume() -> void:
	_inverse_transform = _volume.global_transform.affine_inverse()
	var box: BoxShape3D = _volume.shape as BoxShape3D
	var sphere: SphereShape3D = _volume.shape as SphereShape3D
	_valid_volume = box != null or sphere != null
	_sphere_radius_squared = sphere.radius * sphere.radius if sphere != null else 0.0
	if box != null:
		_box_bounds = AABB(-box.size * 0.5, box.size)

## Читает авторитетный выключатель и уже работающие часы визуального мерцания.
func is_lit() -> bool:
	return enabled and (circuit_id.is_empty() or LightCircuitService.is_enabled(circuit_id)) and (not is_instance_valid(_flicker_view) or _flicker_view.is_lit())
#endregion
