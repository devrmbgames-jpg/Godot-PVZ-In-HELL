extends GameDefinition
## One authored NPC ability. C_NpcCombat owns separate melee/ranged slots.
class_name DEF_NpcAttack

@export var damage: float = 12.0
@export var minimum_range: float = 0.0
@export var maximum_range: float = 1.8
@export var windup_seconds: float = 0.45
@export var active_seconds: float = 0.2
@export var recovery_seconds: float = 0.4
@export var cooldown_seconds: float = 1.2
## Nonempty, available animation uses npc_attack_hit()/npc_attack_finished() method tracks.
@export var animation: StringName = &""
@export_flags_3d_physics var collision_mask: int = 31
@export var projectile_speed: float = 9.0
@export var projectile_lifetime: float = 3.0
