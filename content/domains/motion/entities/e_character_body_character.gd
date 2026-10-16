@tool
extends E_PhysicalCharacter
## Связь Entity с CharacterBody: ввод готовят Systems, движение исполняет физический callback.
class_name E_CharacterBodyCharacter

## Луч фактической опоры для передачи импульса её RigidBody.
@export var ground_ray: RayCast3D = null
## Optional authored broadphase probe: samples incoming native velocity before Jolt resolves a hit.
@export var incoming_impact_probe: ShapeCast3D = null


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


#region Явные физические границы
## Производная политика участия; подклассы читают свои authoritative lifecycle Components.
func physical_motion_allowed() -> bool:
	return true


## Сбрасывает transient движение при размещении, сне, смерти или физическом ограничении.
func clear_physical_motion(reset_contacts: bool = false) -> void:
	var body: CharacterBody3D = self as Node as CharacterBody3D
	body.velocity = Vector3.ZERO
	var motion: C_Motion = get_component(C_Motion) as C_Motion
	if motion != null:
		motion.pending_impulse = Vector3.ZERO
		motion.floor_snap_blocked = false
		motion.is_on_floor = false
		motion.floor_body_rid = RID()
		motion.floor_velocity = Vector3.ZERO
	var config: C_CharacterBody = get_component(C_CharacterBody) as C_CharacterBody
	if config != null:
		config.impulse_velocity = Vector3.ZERO
		config.pending_rebound_velocity = Vector3.ZERO
		if reset_contacts:
			KinematicImpactCapture.reset_contacts(self, body, config)


## Взгляд игрока сохраняет доступ к поясу; NPC переопределяет только этот вклад.
func update_physical_look(
	body: CharacterBody3D,
	control: C_Controller,
	config: C_CharacterBody,
	delta: float,
) -> void:
	KinematicCharacterSolver.update_view(self, body, control, config, delta)
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
		if not physical_motion_allowed():
			clear_physical_motion()
			KinematicImpactCapture.capture_stationary(self, body, config, incoming_impact_probe)
			return
		update_physical_look(body, control, config, delta)
		# Native motion owns the slide; each independent contact contribution observes that same
		# step.
		var sample: KinematicMotionSample = (
			KinematicCharacterSolver.step(self, body, control, motion, config, delta)
		)
		KinematicPushSolver.push_contacts(self, body, config, sample.desired_velocity, delta)
		KinematicImpactCapture.capture(
			self,
			body,
			config,
			sample.incoming_velocity,
			incoming_impact_probe,
		)
		KinematicCharacterSolver.update_support(self, body, motion, config, delta)

#endregion
