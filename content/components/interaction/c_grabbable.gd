extends Component
class_name C_Grabbable

@export var hold_distance: float = 1.75
## Spring coefficients are acceleration gains; the solver accounts for body mass.
@export var position_stiffness: float = 110.0
@export var position_damping: float = 22.0
@export var rotation_stiffness: float = 45.0
@export var rotation_damping: float = 14.0
@export var max_hold_force: float = 12000.0
@export var max_hold_torque: float = 2500.0
@export var break_distance: float = 4.0
## Desired velocity change. Heavy-object profiles use a smaller value.
@export var throw_velocity: float = 10.0
@export_range(0.0, 1.0, 0.01) var movement_speed_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var movement_acceleration_multiplier: float = 1.0
