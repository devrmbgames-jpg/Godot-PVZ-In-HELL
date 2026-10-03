extends RefCounted
## Detached decision result. Opponent authority remains the actor's R_CombatTarget.
class_name NpcAttackChoice

var kind: C_NpcCombat.Kind = C_NpcCombat.Kind.MELEE
var variant: int = -1
var priority: float = 0.0
var damage_rate: float = 0.0

