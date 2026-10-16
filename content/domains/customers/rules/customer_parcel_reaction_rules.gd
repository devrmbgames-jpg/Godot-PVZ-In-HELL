extends RefCounted
## Pure wrong-parcel choice from an authored capability and captured rolls; never rolls or commits.
class_name CustomerParcelReactionRules

enum Outcome {
	INVALID,
	REFUSE,
	KEEP,
	THROW_AT_PLAYER,
	THROW_ASIDE,
	BURN,
	DAMAGE,
}

## NONE is an unattempted demand; INVALID is rejected input and must never be committed.
enum DemandOutcome {
	NONE,
	ATTACK,
	RETURN,
	INVALID,
}

const DEMAND_BASE_ATTACK: float = 0.5
const DEMAND_ATTACK_PER_STRENGTH: float = 0.05
const DEMAND_MIN_ATTACK: float = 0.05
const DEMAND_MAX_ATTACK: float = 0.95


#region Explicit probability model
## Rolls are finite values in [0, 1], including native RNG endpoint values.
## Callers own correct-order eligibility, remaining cargo, incident identity and RNG sequences.
static func choose(
	rule: DEF_NpcParcelReaction,
	holy_contents: bool,
	fire_destructible: bool,
	primary_roll: float,
	secondary_roll: float,
) -> Outcome:
	for roll: float in [primary_roll, secondary_roll]:
		if not is_finite(roll) or roll < 0.0 or roll > 1.0:
			return Outcome.INVALID
	if rule == null:
		return Outcome.REFUSE
	if not rule.valid_configuration():
		return Outcome.INVALID
	var rejects_holy: bool = holy_contents and rule.rejects_holy
	if rejects_holy and rule.holy_rejection_first:
		return Outcome.THROW_ASIDE

	var outcome: Outcome = Outcome.REFUSE
	match rule.mode:
		DEF_NpcParcelReaction.Mode.TAKE_OR_THROW:
			if _wins(primary_roll, rule.take_probability):
				outcome = Outcome.KEEP
			elif _wins(secondary_roll, rule.throw_after_not_taken_probability):
				outcome = Outcome.THROW_AT_PLAYER
		DEF_NpcParcelReaction.Mode.FIRE:
			var burn_probability: float = rule.burn_probability if fire_destructible else 0.0
			if _wins(primary_roll, burn_probability):
				outcome = Outcome.BURN
			elif rule.damage_after_not_burned:
				if _wins(secondary_roll, rule.damage_probability):
					outcome = Outcome.DAMAGE
			elif _wins(primary_roll, burn_probability + rule.damage_probability):
				outcome = Outcome.DAMAGE
	if rejects_holy and outcome == Outcome.REFUSE:
		return Outcome.THROW_ASIDE
	return outcome


static func _wins(roll: float, probability: float) -> bool:
	# A probability of one always succeeds, even if a native generator returns its upper endpoint.
	return probability > 0.0 and (roll < probability or probability == 1.0)
#endregion


#region Explicit intimidation choice
## One attack-or-return choice from effective Strength and one captured native roll in [0, 1].
## Strength is finite and signed; the owner's clamp applies to both ends without rounding.
## Eligibility, capturing Strength/RNG and committing the result belong to the incident owner.
static func choose_demand(strength: float, roll: float) -> DemandOutcome:
	if not is_finite(strength) or not is_finite(roll) or roll < 0.0 or roll > 1.0:
		return DemandOutcome.INVALID
	var attack_probability: float = clampf(
		DEMAND_BASE_ATTACK - DEMAND_ATTACK_PER_STRENGTH * strength,
		DEMAND_MIN_ATTACK,
		DEMAND_MAX_ATTACK,
	)
	return DemandOutcome.ATTACK if _wins(roll, attack_probability) else DemandOutcome.RETURN
#endregion
