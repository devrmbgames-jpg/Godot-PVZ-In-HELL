extends RefCounted
## Explicit native support probe; cargo ownership remains the authoritative live Relationship.
class_name CartCargoGeometry

const SUPPORT_DISTANCE: float = 0.06
const MIN_SUPPORT_NORMAL: float = 0.7

#region Native support geometry
## Tests real physical support on the cart or already-bound stacked cargo.
static func supported(body: RigidBody3D, cart: Entity) -> bool:
	var contact: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(body.global_transform, Vector3.DOWN * SUPPORT_DISTANCE, contact):
		return false
	if contact.get_normal().y < MIN_SUPPORT_NORMAL:
		return false

	var support: Entity = contact.get_collider() as Node as Entity
	if support == cart:
		return true
	if not is_instance_valid(support):
		return false

	var binding: Relationship = CartCargoService.relationship(support)
	return binding != null and binding.target == cart


#endregion
