extends Component
class_name C_GrabControl

var rotation_active: bool = false
## Derived reverse index maintained by O_GrabLifecycle and checked against the relation.
## Never assign this to acquire ownership.
var held_object: Entity = null
