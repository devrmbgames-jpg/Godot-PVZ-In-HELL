@tool
extends Entity
## Routes the body's physics callback to transport restraint or physical holding.
class_name E_GrabbableBody


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	ImpactCaptureSolver.capture(self, state)
	if CartCargoSolver.integrate(self, state):
		return
	S_Grab.integrate_forces(self, state)
