@tool
extends Entity
## Scene glue for constrained physical leaves; joints/bodies own movement.
class_name E_Openable

@export var door_root: RigidBody3D = null
@export var hinge_joint: HingeJoint3D = null
@export var slide_joint: Generic6DOFJoint3D = null


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint() and is_instance_valid(door_root):
		OpenableJointSolver.step(self, door_root, hinge_joint, slide_joint)
