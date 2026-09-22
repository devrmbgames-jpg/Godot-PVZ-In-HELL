extends Component
class_name C_Grabbable

enum HoldSlot { CARRY, RIGHT_HAND }

## Tools/weapons use RIGHT_HAND; ordinary parcels use CARRY.
@export var hold_slot: HoldSlot = HoldSlot.CARRY
## Negative means use the holder's C_GrabControl.hold_distance. Ignored for hand slots.
@export var hold_distance: float = -1.0
## Spring coefficients are acceleration gains; the solver accounts for body mass.
@export var position_stiffness: float = 110.0
@export var position_damping: float = 22.0
## Angular velocity servo: no spring momentum while held; collisions remain physical.
@export var max_rotation_speed: float = 30.0
@export var max_hold_force: float = 12000.0
@export var break_distance: float = 4.0
## Desired velocity change. Heavy-object profiles use a smaller value.
@export var throw_velocity: float = 10.0
@export_range(0.0, 1.0, 0.01) var movement_speed_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var movement_acceleration_multiplier: float = 1.0
