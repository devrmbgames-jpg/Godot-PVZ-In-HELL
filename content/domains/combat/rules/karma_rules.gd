extends RefCounted
## Pure alignment validation and strict low/high classification without changing player state.
class_name KarmaRules


#region Policy and persistent state
## Requires finite ordered bounds with a neutral interval between the two thresholds.
static func valid_policy(policy: DEF_KarmaPolicy) -> bool:
	return (
		policy != null and is_finite(policy.minimum_value)
		and is_finite(policy.maximum_value) and is_finite(policy.low_threshold)
		and is_finite(policy.high_threshold) and policy.minimum_value < policy.low_threshold
		and policy.low_threshold < policy.high_threshold
		and policy.high_threshold < policy.maximum_value
	)


## Invalid saved values are rejected rather than silently clamped during reconstruction.
static func valid(karma: C_Karma) -> bool:
	return (
		valid_policy(karma.policy) and is_finite(karma.value)
		and karma.value >= karma.policy.minimum_value and karma.value <= karma.policy.maximum_value
	)


## The low threshold itself is neutral for holy receiver selection.
static func is_low(karma: C_Karma) -> bool:
	return valid(karma) and karma.value < karma.policy.low_threshold


## The high threshold itself is neutral for unholy receiver selection.
static func is_high(karma: C_Karma) -> bool:
	return valid(karma) and karma.value > karma.policy.high_threshold

#endregion
