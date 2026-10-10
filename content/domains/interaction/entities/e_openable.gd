@tool
extends E_TraitedEntity
## Связывает сцену физической створки с solver; движение исполняют joint и тело.
class_name E_Openable

## Подвижное физическое тело створки или ящика.
@export var door_root: RigidBody3D = null
## Необязательный шарнир; при наличии имеет приоритет над линейным joint.
@export var hinge_joint: HingeJoint3D = null
## Необязательный линейный joint для выдвижного тела без шарнира.
@export var slide_joint: Generic6DOFJoint3D = null


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint() and is_instance_valid(door_root):
		OpenableJointSolver.step(self, door_root, hinge_joint, slide_joint)
