extends Area3D
## Authored gameplay light volume; moving player lights can use the same Area3D.
class_name NpcLightZone

## Light exposure inside the volume, normalized to 0..1.
@export_range(0.0, 1.0) var exposure: float = 1.0
## Independent source toggle, used by a future carried light.
@export var enabled: bool = true
## Enable for a carried light; static room volumes capture their geometry once.
@export var moving_source: bool = false
## Optional stable switch ID; an empty ID makes the zone independent.
@export var circuit_id: StringName = &""
## Optional existing visual clock, keeping circuit flicker synchronized.
@export var flicker_view_path: NodePath = NodePath("")

@onready var _volume: CollisionShape3D = $CollisionShape3D
@onready var _flicker_view: CircuitLightView = get_node_or_null(flicker_view_path) as CircuitLightView if not flicker_view_path.is_empty() else null

var _inverse_transform: Transform3D = Transform3D.IDENTITY
var _box_bounds: AABB = AABB()
var _sphere_radius_squared: float = 0.0
var _valid_volume: bool = false

#region Registration
func _enter_tree() -> void:
	NpcLightingService.register_zone(self)

func _ready() -> void:
	_capture_volume()

func _exit_tree() -> void:
	NpcLightingService.unregister_zone(self)
#endregion

#region Volume query
## Tests a single authored box or sphere, without physics rays or light-source searches.
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

## Reads the authoritative switch and the already-running visual flicker clock.
func is_lit() -> bool:
	return enabled and (circuit_id.is_empty() or LightCircuitService.is_enabled(circuit_id)) and (not is_instance_valid(_flicker_view) or _flicker_view.is_lit())
#endregion
