extends DEF_ChallengeCondition
class_name DEF_GazeChallengeCondition

@export var required_attention: bool = false
@export_range(1.0, 89.0) var half_angle_degrees: float = 20.0
@export_range(0.1, 100.0) var maximum_distance: float = 12.0
## World, customers, packages and physical props; player body is excluded explicitly.
@export_flags_3d_physics var collision_mask: int = 27
@export_range(0.0, 0.99) var warning_fraction: float = 0.5
@export_multiline var warning_text: String = "Не смотрите на меня!"
