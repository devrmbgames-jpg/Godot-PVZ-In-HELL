@tool
extends Entity
class_name E_GrabbableBody


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	S_Grab.integrate_forces(self, state)
