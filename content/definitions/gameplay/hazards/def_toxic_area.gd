extends DEF_Hazard
## Reusable toxic volume tuning; eligible receivers are chosen independently of Package type.
class_name DEF_ToxicArea

## Sphere radius in meters and periodic HP loss; first tick occurs after one full interval.
@export_range(0.1, 100.0) var radius: float = 2.0
@export_range(0.05, 60.0) var tick_seconds: float = 1.0
@export_range(0.0, 10000.0) var damage_per_tick: float = 5.0
## Spatial broad phase and semantic eligibility; living-only includes future Customer actors.
@export_flags_3d_physics var collision_mask: int = 31
@export var living_only: bool = true
