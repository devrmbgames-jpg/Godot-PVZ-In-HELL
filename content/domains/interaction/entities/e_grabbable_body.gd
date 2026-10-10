@tool
extends E_TraitedEntity
## В физическом callback фиксирует удар и передаёт исполнение грузу тележки либо удержанию.
class_name E_GrabbableBody


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	ImpactCaptureSolver.capture(self, state)
	if CartCargoSolver.integrate(self, state):
		return

	GrabPhysicsSolver.integrate_forces(self, state)
