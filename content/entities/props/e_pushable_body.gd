@tool
extends Entity
## Forwards cart body integration to its Push solver without owning gameplay state.
class_name E_PushableBody


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	S_Push.integrate_cart(self, state)
