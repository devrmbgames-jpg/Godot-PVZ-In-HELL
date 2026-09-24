extends Component
## Actor hold configuration, derived slot caches and shared interaction control state.
class_name C_GrabControl

const NO_CARRY_GROUP: StringName = &"no_carry"

## Maximum reach for picking up an object (metres).
@export_range(0.1, 10.0, 0.1, "or_greater") var pickup_distance: float = 3.0
## Distance in front of Holder for ordinary carried objects (metres).
@export_range(0.1, 5.0, 0.05, "or_greater") var hold_distance: float = 1.25
var rotation_active: bool = false
## Derived reverse index maintained by O_GrabLifecycle and checked against the relation.
## Never assign this to acquire ownership.
var held_carry: Entity = null
var held_right: Entity = null
var held_left: Entity = null
## Swaps primary/secondary controls without moving objects between physical hands.
@export var swap_hand_controls: bool = false
## Holding G beyond this time reserves the future context wheel and suppresses drop.
@export_range(0.1, 2.0, 0.05) var drop_long_press_seconds: float = 0.45
## Token registry is the single control-focus authority; each acquire has its own key.
var captures: Dictionary[int, InteractionControlCapture] = { }
var context_wheel_requested: bool = false


## Generic physical Carry candidate independent of the holder's current Strength.
func is_carry_candidate(body: RigidBody3D) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	if not body.is_inside_tree() or body.freeze or body.is_in_group(NO_CARRY_GROUP):
		return false
	return is_finite(body.mass) and body.mass > 0.0


## True only when mass is the reason a valid Carry candidate cannot be lifted.
func is_too_heavy(body: RigidBody3D, strength: C_Strength) -> bool:
	return (
		is_carry_candidate(body)
		and strength != null
		and not CarryLoadPolicy.can_carry(body.mass, strength)
	)


## Generic Carry eligibility for authored or completely scriptless rigid bodies.
func can_carry_body(body: RigidBody3D, strength: C_Strength) -> bool:
	return is_carry_candidate(body) and CarryLoadPolicy.can_carry(body.mass, strength)
