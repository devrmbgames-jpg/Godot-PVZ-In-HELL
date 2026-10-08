@tool
extends E_PhysicalCharacter
## Связь Entity с CharacterBody: ввод готовят Systems, движение исполняет физический callback.
class_name E_CharacterBodyPlayer

## Луч фактической опоры для передачи импульса её RigidBody.
@export var ground_ray: RayCast3D = null


#region Подготовка физических исключений
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var body: CharacterBody3D = self as Node as CharacterBody3D
	assert(body != null)
	# Свои поясные узлы доступны взаимодействию, но исключены из столкновений тела и луча опоры.
	for node: Node in find_children("*", "PhysicsBody3D", true, false):
		var child: PhysicsBody3D = node as PhysicsBody3D
		body.add_collision_exception_with(child)
		if ground_ray != null:
			ground_ray.add_exception(child)


#endregion

#region Исполнение физического шага
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not EntityAvailability.contains(self, ECS.world):
		return

	var body: CharacterBody3D = self as Node as CharacterBody3D
	var motion: C_Motion = get_component(C_Motion) as C_Motion
	var control: C_Controller = get_component(C_Controller) as C_Controller
	var config: C_CharacterBody = get_component(C_CharacterBody) as C_CharacterBody
	if body != null and motion != null and control != null and config != null:
		# Native motion owns the slide; each independent contact contribution observes that same step.
		var sample: KinematicMotionSample = KinematicCharacterSolver.step(self, body, control, motion, config, delta)
		KinematicPushSolver.push_contacts(self, body, config, sample.desired_velocity, delta)
		KinematicImpactCapture.capture(self, body, config, sample.incoming_velocity)
		KinematicCharacterSolver.update_support(self, body, motion, config, delta)

#endregion
