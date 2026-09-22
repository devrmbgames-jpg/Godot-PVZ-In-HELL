extends Component
class_name C_HeldBy

var slot: C_Grabbable.HoldSlot = C_Grabbable.HoldSlot.CARRY
var rotation_offset: Quaternion = Quaternion.IDENTITY
var hold_distance: float = 0.0
## Lifecycle bookkeeping; these fields are not an alternative ownership flag.
var previous_can_sleep: bool = true
var added_collision_exception: bool = false
var previous_anchor_position: Vector3 = Vector3.ZERO
var anchor_sample_valid: bool = false
## Set only after observer side effects, cleared on teardown; never used to infer ownership.
var lifecycle_applied: bool = false
