extends Component
## Authoritative cargo-to-cart binding and reversible restraint lifecycle state.
class_name R_CartCargo

var local_pose: Transform3D = Transform3D.IDENTITY
var previous_custom_integrator: bool = false
var previous_can_sleep: bool = true
var added_exception: bool = false
var lifecycle_applied: bool = false
