@tool
extends Entity
class_name E_RigidBodyCharacter

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
@export var camera_root: Node3D
@export var ray_standing: RayCast3D

@export_subgroup("Look")
@export var head_axis_y: Node3D
@export var head_axis_x: Node3D


func _init() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	assert(self as Node as RigidBody3D, "is not rigid!")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	ImpactCaptureSolver.capture(self, state)
	if CartDriverSolver.integrate(self, state):
		return
	if PushActorSolver.integrate(self, state):
		return
	CharacterMotionSolver.integrate_forces(self, state)
	CharacterLookSolver.integrate_forces(self, state)
