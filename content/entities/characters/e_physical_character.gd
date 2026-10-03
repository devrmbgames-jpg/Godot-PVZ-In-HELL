@tool
extends Entity
## Shared authored head, collider and interaction anchors for both native character bodies.
class_name E_PhysicalCharacter

@export_subgroup("Interaction")
@export var interaction_ray_cast: RayCast3D = null
@export var hold_anchor: Node3D = null
@export var right_hand_slot: Node3D = null
@export var left_hand_slot: Node3D = null
@export var lowered_right_hand_slot: Node3D = null
@export var lowered_left_hand_slot: Node3D = null

@export_subgroup("Crouch")
@export var shape_standing: CollisionShape3D
@export var shape_crouching: CollisionShape3D
## Shared HeadRoot (camera, interaction ray and hand/hold anchors); path/API is preserved.
@export var camera_root: Node3D
@export var ray_standing: RayCast3D
## Крепления на теле: следуют высоте приседания, не вращению камеры.
@export var crouch_mounts: Array[Node3D] = []

@export_subgroup("Look")
@export var head_axis_y: Node3D
@export var head_axis_x: Node3D
