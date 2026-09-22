extends RefCounted
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

var source: Entity = null
var target: Entity = null
var amount: float = 0.0
var operation: Operation = Operation.DAMAGE
var damage_type: Type = Type.GENERIC
