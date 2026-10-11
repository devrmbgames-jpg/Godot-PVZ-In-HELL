extends RefCounted
## Explicit synchronous alignment operations; C_Karma remains the sole mutable authority.
class_name KarmaService


#region Alignment operations
## Applies a finite absolute value, clamping ordinary gameplay changes to authored bounds.
static func set_value(actor: Entity, value: float) -> bool:
	var karma: C_Karma = actor.get_component(C_Karma) as C_Karma
	assert(karma != null, "Alignment operations require the authored C_Karma capability")
	if not is_finite(value) or not KarmaRules.valid(karma):
		return false

	karma.value = clampf(value, karma.policy.minimum_value, karma.policy.maximum_value)
	return true


## Applies one finite delta through the same bounds and validation boundary.
static func adjust(actor: Entity, delta: float) -> bool:
	var karma: C_Karma = actor.get_component(C_Karma) as C_Karma
	assert(karma != null, "Alignment operations require the authored C_Karma capability")
	if not is_finite(delta):
		return false
	return set_value(actor, karma.value + delta)

#endregion
