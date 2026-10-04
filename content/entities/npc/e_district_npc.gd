@tool
extends E_Customer
## Презентация постоянного NPC и явные границы физического участия и телепортации.
class_name E_DistrictNpc

var _body_layer: int = 2
var _body_mask: int = 31

#region Жизненный цикл движка
func _ready() -> void:
	super._ready()
	var body: RigidBody3D = self as Node as RigidBody3D
	_body_layer = body.collision_layer
	_body_mask = body.collision_mask
#endregion

#region Представление района
## Изменяет физическое участие без удаления или сброса личности.
func set_participating(participating: bool) -> void:
	var body: RigidBody3D = self as Node as RigidBody3D
	body.freeze = not participating
	body.visible = participating
	body.collision_layer = _body_layer if participating else 0
	body.collision_mask = _body_mask if participating else 0
	if not participating:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	sync_navigation_lifecycle(participating)

## Разовая синхронизация при появлении, сне или загрузке; обычным движением владеет физика.
func place_at(world_position: Vector3) -> void:
	var body: RigidBody3D = self as Node as RigidBody3D
	var was_frozen: bool = body.freeze
	body.freeze = true
	body.global_position = world_position
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	body.freeze = was_frozen

## Показывает постоянную личность независимо от активного заказа.
func present_profile(profile: DEF_NpcProfile) -> void:
	show_message(profile.display_name)
	var skeleton_meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = profile.body_color
	for mesh_node: Node in skeleton_meshes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		mesh_instance.material_override = material
#endregion
