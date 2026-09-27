extends DEF_Hazard
## Reusable radial blast tuning, including LOS and physical impulse independent of HP.
class_name DEF_Explosion

## Radius, center damage and center impulse (N*s), with radial power falloff.
@export_range(0.1, 100.0) var radius: float = 4.0
@export_range(0.0, 10000.0) var damage: float = 60.0
@export_range(0.0, 10000.0) var impulse: float = 80.0
## Adds an upward component before normalization so grounded bodies visibly leave the floor.
@export_range(0.0, 2.0, 0.05) var upward_bias: float = 0.25
@export_range(0.1, 8.0) var falloff_power: float = 1.0
## Broad-phase targets. Keep physical props/actors here; Environment may be included for
## destructible world bodies, but static environment is filtered before impulse/damage.
@export_flags_3d_physics var target_mask: int = 31
## One center-to-target ray; only authored blocking environment belongs here.
@export_flags_3d_physics var obstacle_mask: int = 1
## Bound spatial work; large scenes can raise this authored cap.
@export_range(1, 1024) var maximum_targets: int = 128
