@tool
extends E_PhysicalCharacter
class_name E_RigidBodyCharacter



func _init() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
	assert(self as Node as RigidBody3D, "is not rigid!")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	ImpactCaptureSolver.capture(self, state)
	if CartDriverSolver.integrate(self, state):
		# Transport replaces locomotion, not look: S_PlayerIntent keeps
		# direction_look aligned with the cart while steering.
		CharacterLookSolver.integrate_forces(self, state)
		return
	if PushActorSolver.integrate(self, state):
		return

	CharacterMotionSolver.integrate_forces(self, state)
	CharacterLookSolver.integrate_forces(self, state)
