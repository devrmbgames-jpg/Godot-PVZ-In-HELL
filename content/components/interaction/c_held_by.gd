extends Component
## Authoritative item-to-holder slot relation and reversible grip integration state.
class_name C_HeldBy

var slot: C_Grabbable.HoldSlot = C_Grabbable.HoldSlot.CARRY
## Snapshot of the effective authored/default policy used by this grip.
var profile: GrabControlProfile = null
var rotation_offset: Quaternion = Quaternion.IDENTITY
var hold_distance: float = 0.0
## Lifecycle bookkeeping; these fields are not an alternative ownership flag.
var previous_can_sleep: bool = true
var added_collision_exception: bool = false
var previous_anchor_position: Vector3 = Vector3.ZERO
var anchor_sample_valid: bool = false
var previous_anchor_id: int = 0
var anchor_transition_remaining: float = 0.0
var capture_token: int = 0
## Set only after observer side effects, cleared on teardown; never used to infer ownership.
var lifecycle_applied: bool = false
