@tool
extends DEF_NpcTrait
## Immutable wrong-parcel policy; the incident owner commits a choice before any physical effect.
class_name DEF_NpcParcelReaction

enum Mode {
	REFUSE,
	TAKE_OR_THROW,
	FIRE,
}

## Selects the probability model, independently of archetype ID or display name.
@export var mode: Mode = Mode.REFUSE
## Actual holy contents trigger a physical rejection for this receiver.
@export var rejects_holy: bool = false
## Holy rejection precedes ordinary outcomes; false applies it only after an ordinary refusal.
@export var holy_rejection_first: bool = true
## TAKE_OR_THROW: first probability of keeping the wrong parcel.
@export_range(0.0, 1.0) var take_probability: float = 0.0
## TAKE_OR_THROW: conditional probability of throwing after the parcel was not kept.
@export_range(0.0, 1.0) var throw_after_not_taken_probability: float = 0.0
## FIRE: probability of burning an eligible payload; ineligible contents retain zero burn chance.
@export_range(0.0, 1.0) var burn_probability: float = 0.0
## FIRE: box-damage probability; absolute by default, independent of payload burn eligibility.
@export_range(0.0, 1.0) var damage_probability: float = 0.0
## False shares one absolute burn/damage/refusal partition; true uses a second conditional roll.
@export var damage_after_not_burned: bool = false
## FIRE damage outcome: positive HP amount, independently authored from its probability.
@export_range(0.1, 1000.0, 0.1) var damage_amount: float = 20.0


#region Authored capability validation
func _init() -> void:
	kind = Kind.CAPABILITY


func valid_configuration() -> bool:
	if kind != Kind.CAPABILITY:
		return false
	if not is_finite(damage_amount) or damage_amount <= 0.0:
		return false
	for probability: float in [
		take_probability,
		throw_after_not_taken_probability,
		burn_probability,
		damage_probability,
	]:
		if not is_finite(probability) or probability < 0.0 or probability > 1.0:
			return false
	match mode:
		Mode.REFUSE:
			return (
				take_probability == 0.0 and throw_after_not_taken_probability == 0.0
				and burn_probability == 0.0 and damage_probability == 0.0
			)
		Mode.TAKE_OR_THROW:
			return burn_probability == 0.0 and damage_probability == 0.0
		Mode.FIRE:
			return (
				take_probability == 0.0 and throw_after_not_taken_probability == 0.0
				and (damage_after_not_burned or burn_probability + damage_probability <= 1.0)
			)
	return false
#endregion
