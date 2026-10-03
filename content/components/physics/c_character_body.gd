extends Component
## Authored kinematic response and derived impulse/contact data; native body owns total velocity.
class_name C_CharacterBody

@export var gravity_scale: float = 1.0
@export var mass_kg: float = 60.0
@export var impulse_decay_per_second: float = 8.0
@export var impact_rebound_fraction: float = 0.35
@export var maximum_rebound_speed: float = 8.0
@export var ground_impulse_per_second: float = 6.0
@export var ground_maximum_velocity_change: float = 0.8
@export var slot_look_down_degrees: float = 55.0
@export var step_height: float = 0.2
## Обычное движение сдвигает свободные лёгкие тела; тяжёлая мебель требует отдельного действия.
@export_range(0.0, 100.0, 0.5, "or_greater") var walk_push_maximum_mass: float = 15.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var walk_push_force: float = 180.0
@export_range(0.0, 10.0, 0.1, "or_greater") var walk_push_maximum_speed: float = 3.0

## Planar gameplay impulse contribution, separate from controlled locomotion.
var impulse_velocity: Vector3 = Vector3.ZERO
## Contact solver requests; consumed only by the owning native physics callback.
var pending_rebound_velocity: Vector3 = Vector3.ZERO
## Derived physical contact cache for separation reports, never an ownership/session binding.
var contact_bodies: Dictionary[int, WeakRef] = {}
