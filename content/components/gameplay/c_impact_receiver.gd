extends Component
## Receiver-side tuning for generic physical impacts; requires C_Health.
class_name C_ImpactReceiver

## Closing normal speed (m/s) and measured normal impulse (N*s) below which contact is harmless.
@export_range(0.0, 50.0) var minimum_speed: float = 2.5
@export_range(0.0, 1000.0) var minimum_impulse: float = 0.5
## Damage per transferred joule and energy absorbed without HP loss.
@export_range(0.0, 10.0) var damage_per_joule: float = 0.15
@export_range(0.0, 10000.0) var absorption_joules: float = 5.0
## Damage thresholds used for feedback severity, not a replacement for numeric HP damage.
@export var medium_damage: float = 8.0
@export var strong_damage: float = 30.0
