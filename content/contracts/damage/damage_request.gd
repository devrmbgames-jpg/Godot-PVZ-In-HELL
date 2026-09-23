extends RefCounted
## Typed queued damage/heal intent with separate damaging source and actor attribution.
class_name DamageRequest

enum Operation {
	DAMAGE,
	HEAL,
}
enum Type {
	GENERIC,
	MELEE,
	IMPACT,
	EXPLOSION,
	TOXIC,
}

## Actual damaging body and optional actor who caused its action.
var instigator: Entity = null
var source: Entity = null
var target: Entity = null
var amount: float = 0.0
var operation: Operation = Operation.DAMAGE
var damage_type: Type = Type.GENERIC
