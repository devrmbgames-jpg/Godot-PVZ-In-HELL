extends RefCounted
## Typed queued damage/heal intent with separate damaging source and actor attribution.
class_name DamageRequest

const EVENT := &"damage_requested"

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
	LIQUID,
}

## Actual damaging body and optional actor who caused its action.
var instigator: Entity = null
var source: Entity = null
var target: Entity = null
var amount: float = 0.0
var operation: Operation = Operation.DAMAGE
var damage_type: Type = Type.GENERIC

## Durable effect attribution, independent of live origin/instigator Node references.
var origin_id: String = ""
var instigator_id: String = ""
