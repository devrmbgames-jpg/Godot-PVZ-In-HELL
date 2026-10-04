@tool
extends E_PhysicalCharacter
## Thin engine glue; input remains in Systems and movement in the native body callback.
class_name E_CharacterBodyPlayer

@export var ground_ray: RayCast3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var body: CharacterBody3D = self as Node as CharacterBody3D
	assert(body != null)
	# Own belt handles remain ray targets but cannot collide with their host body/ground ray.
	for node: Node in find_children("*", "PhysicsBody3D", true, false):
		var child: PhysicsBody3D = node as PhysicsBody3D
		body.add_collision_exception_with(child)
		if ground_ray != null:
			ground_ray.add_exception(child)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not EntityAvailability.contains(self, ECS.world):
		return

	var body: CharacterBody3D = self as Node as CharacterBody3D
	var motion: C_Motion = get_component(C_Motion) as C_Motion
	var control: C_Controller = get_component(C_Controller) as C_Controller
	var config: C_CharacterBody = get_component(C_CharacterBody) as C_CharacterBody
	if body != null and motion != null and control != null and config != null:
		KinematicCharacterSolver.step(self, body, control, motion, config, delta)
