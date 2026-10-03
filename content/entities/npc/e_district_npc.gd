@tool
extends E_Customer
## Persistent NPC presentation and explicit native participation/teleport boundaries.
class_name E_DistrictNpc

var _body_layer: int = 2
var _body_mask: int = 31

#region Engine lifecycle
func _ready() -> void:
	super._ready()
	var body: RigidBody3D = self as Node as RigidBody3D
	_body_layer = body.collision_layer
	_body_mask = body.collision_mask
#endregion

#region District presentation
## Changes physics participation without deleting or resetting the person.
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

## One-time synchronization at spawn, sleep or load, never ordinary movement.
func place_at(world_position: Vector3) -> void:
	var body: RigidBody3D = self as Node as RigidBody3D
	var was_frozen: bool = body.freeze
	body.freeze = true
	body.global_position = world_position
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	body.freeze = was_frozen

## Presents a stable person independently of the active parcel case.
func present_profile(profile: DEF_NpcProfile) -> void:
	show_message(profile.display_name)
	var skeleton_meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = profile.body_color
	for mesh_node: Node in skeleton_meshes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		mesh_instance.material_override = material
#endregion
