@tool
extends Component
## Authored contact capability; the impact System owns episode deduplication.
class_name C_ContactDamage

## Health damage before resistance, replacing ordinary impact damage for this source.
@export_range(0.0, 10000.0) var damage: float = 12.0
## Semantic health channel; physical impulse remains owned by native physics.
@export var damage_type: DamageRequest.Type = DamageRequest.Type.MELEE
## Minimum positive normal approach speed in metres per second; resting reports cannot cut.
@export_range(0.0, 50.0) var minimum_speed: float = 0.5
## Minimum positive contact impulse in newton seconds.
@export_range(0.0, 1000.0) var minimum_impulse: float = 0.1
