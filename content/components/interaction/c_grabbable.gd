extends Component
## Authored hold, throw, Carry penalty and manual rotation policy for a physical prop.
class_name C_Grabbable

enum HoldSlot {
	CARRY,
	RIGHT_HAND,
	LEFT_HAND,
}
enum RotationAxis {
	FREE,
	Y_ONLY,
}

## Zero means Carry-only. Hand items declare allowed physical hands.
@export_flags("Right:2", "Left:4") var allowed_hand_slots: int = 0
## Disables both manual rotation input and its contextual prompt when false.
@export var manual_rotation_enabled: bool = true
## Constrains manual rotation offset relative to the selected anchor.
@export var rotation_axis: RotationAxis = RotationAxis.FREE
## Uses the authored anchor orientation instead of preserving relative world rotation.
@export var reset_rotation_on_pickup: bool = false
## Negative means use the holder's C_GrabControl.hold_distance. Ignored for hand slots.
@export var hold_distance: float = -1.0
## Spring coefficients are acceleration gains; the solver accounts for body mass.
@export var position_stiffness: float = 110.0
## Damps relative anchor/body motion to prevent oscillation.
@export var position_damping: float = 22.0
## Angular velocity servo: no spring momentum while held; collisions remain physical.
@export var max_rotation_speed: float = 30.0
## Maximum translation force applied by the hold spring, in newtons.
@export var max_hold_force: float = 12000.0
## Excessive distance from the desired hold position releases the grip.
@export var break_distance: float = 4.0
## Desired velocity change. Heavy-object profiles use a smaller value.
@export var throw_velocity: float = 10.0
## Speed penalty while this item occupies Carry; hand-items do not apply it.
@export_range(0.0, 1.0, 0.01) var movement_speed_multiplier: float = 1.0
## Acceleration penalty while this item occupies Carry.
@export_range(0.0, 1.0, 0.01) var movement_acceleration_multiplier: float = 1.0
