@tool
extends Entity
## Routes the body's physics callback to its current holder or transport restraint.
class_name E_GrabbableBody


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	ImpactCaptureSolver.capture(self, state)
	if S_CartCargo.integrate(self, state):
		return
	S_Grab.integrate_forces(self, state)
