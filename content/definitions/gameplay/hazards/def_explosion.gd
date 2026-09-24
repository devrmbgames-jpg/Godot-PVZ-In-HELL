extends DEF_Hazard
## Reusable radial blast tuning, including LOS and physical impulse independent of HP.
class_name DEF_Explosion

## Radius, center damage and center impulse (N*s), with radial power falloff.
@export_range(0.1, 100.0) var radius: float = 4.0
@export_range(0.0, 10000.0) var damage: float = 60.0
@export_range(0.0, 10000.0) var impulse: float = 80.0
@export_range(0.1, 8.0) var falloff_power: float = 1.0
## One center-to-target ray; any authored blocking layer fully absorbs the blast.
@export_flags_3d_physics var collision_mask: int = 31
@export_flags_3d_physics var obstacle_mask: int = 1
## Bound spatial work; large scenes can raise this authored cap.
@export_range(1, 1024) var maximum_targets: int = 128
