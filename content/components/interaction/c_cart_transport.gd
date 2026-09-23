extends Component
## Authored QoL cart motion limits and its exclusive driver session.
class_name C_CartTransport

## Forward/reverse speed in metres per second, independent of load mass.
@export var forward_speed: float = 2.0
@export var reverse_speed: float = 1.5
## Acceleration and braking in metres per second squared.
@export var acceleration: float = 5.0
## Keyboard yaw speed in radians per second.
@export var turn_speed: float = 1.2
## Maximum small obstacle height; walls and larger steps remain blocking.
@export var step_height: float = 0.2
## Downward floor attachment distance and acceleration.
@export var floor_snap: float = 0.3
@export var gravity: float = 18.0
## Driver follows this distance behind the cart origin without teleporting.
@export var handle_distance: float = 1.6
@export var follow_speed: float = 5.0
## Stop the cart if the driver cannot physically follow; release only beyond focus distance.
@export var follow_tolerance: float = 0.65
@export var focus_distance: float = 4.0
## Cargo must rest on the deck or supported cargo before transport assistance engages.
@export var cargo_settle_seconds: float = 0.15
@export var cargo_settle_speed: float = 0.5
## Bounded rigid-body correction; obstructed cargo detaches instead of crossing walls.
@export var cargo_follow_speed: float = 8.0
@export var cargo_break_distance: float = 0.35
## Derived loaded-body list and transient settling timers; S_CartCargo is their writer.
var cargo: Array[Entity] = []
var settling: Dictionary[int, float] = { }
## Cart-side session authority; only S_CartTransport changes it.
var driver: Entity = null
var capture_token: int = 0
## Smoothed signed drive speed and actual physics displacement velocity.
var drive_speed: float = 0.0
var actual_velocity: Vector3 = Vector3.ZERO
