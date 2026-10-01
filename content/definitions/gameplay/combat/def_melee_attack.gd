extends GameDefinition
## Authored Player weapon strike timing and geometry. NPC variants use DEF_NpcAttack.
class_name DEF_MeleeAttack

@export var damage: float = 25.0
@export var reach: float = 2.0
@export var half_angle_degrees: float = 60.0
@export var windup_seconds: float = 0.25
@export var active_seconds: float = 0.2
@export var recovery_seconds: float = 0.55
@export_flags_3d_physics var collision_mask: int = 31
