extends Resource
## Persistent attribution only; never owns live actor/weapon/target references.
class_name CombatContext

enum Reason { ORDINARY_ATTACK, SELF_DEFENSE, FRAUD_ESCALATION, JUSTIFIED_RETALIATION, CHALLENGE_ESCALATION }

@export var reason: Reason = Reason.ORDINARY_ATTACK
@export var day: int = 0
@export var customer_id: StringName = &""
@export var visit_id: StringName = &""
@export var actor_is_player: bool = false
@export var weapon_key: StringName = &""
