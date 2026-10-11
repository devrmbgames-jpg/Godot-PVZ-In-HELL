extends RefCounted
## Pure supernatural eligibility; player karma takes precedence over authored creature tags.
class_name ReceiverEffectRules

## Exclusion is distinct from either DamageRequest operation.
const EXCLUDED: int = -1


#region Effect validation and receiver selection
## Rejects invalid authoring before a scheduled source can dispatch health requests.
static func valid(profile: DEF_ReceiverEffect) -> bool:
	return (
		profile != null
		and profile.alignment
		in [DEF_ReceiverEffect.Alignment.HOLY, DEF_ReceiverEffect.Alignment.UNHOLY]
		and is_finite(profile.amount_per_tick) and profile.amount_per_tick > 0.0
		and is_finite(profile.tick_seconds) and profile.tick_seconds > 0.0
	)


## Returns a health operation or EXCLUDED; scene/class names never decide receiver meaning.
static func operation_for(target: Entity, alignment: DEF_ReceiverEffect.Alignment) -> int:
	if alignment not in [DEF_ReceiverEffect.Alignment.HOLY, DEF_ReceiverEffect.Alignment.UNHOLY]:
		return EXCLUDED
	var karma: C_Karma = target.get_component(C_Karma) as C_Karma
	if karma != null:
		var eligible: bool = (
			KarmaRules.is_low(karma)
			if alignment == DEF_ReceiverEffect.Alignment.HOLY
			else KarmaRules.is_high(karma)
		)
		return DamageRequest.Operation.DAMAGE if eligible else EXCLUDED

	var receiver: C_ReceiverTraits = target.get_component(C_ReceiverTraits) as C_ReceiverTraits
	if receiver == null:
		return EXCLUDED
	match alignment:
		DEF_ReceiverEffect.Alignment.HOLY:
			if receiver.traits & C_ReceiverTraits.Trait.HOLY_VULNERABLE:
				return DamageRequest.Operation.DAMAGE
		DEF_ReceiverEffect.Alignment.UNHOLY:
			if receiver.traits & C_ReceiverTraits.Trait.UNHOLY_HEALING:
				return DamageRequest.Operation.HEAL
	return EXCLUDED

#endregion
