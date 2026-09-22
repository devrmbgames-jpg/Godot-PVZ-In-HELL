@tool
extends Entity
## Forwards cart body integration to its Push solver without owning gameplay state.
class_name E_PushableBody

@export var exception_collision_list: Array[CollisionObject3D] = []


func _ready() -> void:
	var self_node: Node = self
	var self_rigid: RigidBody3D = self_node as RigidBody3D
	if self_rigid :
		for col in exception_collision_list :
			self_rigid.add_collision_exception_with(col)
			if col is StaticBody3D :
				col.add_collision_exception_with(self_rigid)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	S_Push.integrate_cart(self, state)
