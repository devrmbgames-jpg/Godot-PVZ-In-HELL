extends Component
## Authored drive limits for a physical cart; independent from Grab and hand capacity.
class_name C_Pushable

## Forward motor speed in metres per second; reverse never drives the cart.
@export_range(0.1, 5.0, 0.1) var forward_speed: float = 1.4
## Steering speed in radians per second, independent of mouse sensitivity.
@export_range(0.1, 3.0, 0.1) var turn_speed: float = 0.8
## Maximum actor-to-cart distance before focus breaks.
@export_range(0.5, 6.0, 0.1) var focus_distance: float = 3.0
## Required horizontal view alignment toward the cart.
@export_range(0.0, 1.0, 0.05) var minimum_front_dot: float = 0.25
## Distance behind the cart centre where the player follows its handle.
@export_range(0.5, 3.0, 0.1) var handle_distance: float = 1.3
## Bounded physical correction toward the handle; never writes a transform.
@export_range(0.1, 6.0, 0.1) var follow_speed: float = 2.0
