@tool
extends Entity
class_name E_RigidBodyCharacter

@export_group("Crouch")
@export var shape_standing: CollisionShape3D
@export var shape_crouching: CollisionShape3D
@export var camera_root: Node3D

@export_group("Look")
@export var head_axis_y: Node3D
@export var head_axis_x: Node3D

func _init() -> void:
	if Engine.is_editor_hint() :
		set_physics_process(false)
		set_process(false)
	
	assert(self as Node as RigidBody3D, "is not rigid!")



func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	
	S_Motion.integrate_forces(self, state)
	S_Look.integrate_forces(self, state)
	S_Crouch.integrate_forces(self, state)
