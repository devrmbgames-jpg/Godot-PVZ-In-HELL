extends Component
## Temporary cargo restraint; stores a cart-local pose while the rigid body remains collidable.
class_name C_CartCargo

## Owning transport and settled local pose, written only by S_CartCargo.
var cart: Entity = null
var local_pose: Transform3D = Transform3D.IDENTITY
## Restore the body's original integration/sleep/collision policy on unloading.
var previous_custom_integrator: bool = false
var previous_can_sleep: bool = true
var added_exception: bool = false
