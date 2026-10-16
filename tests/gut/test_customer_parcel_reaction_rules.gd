extends GutTest
## Deterministic boundary checks for authored wrong-parcel choices; no Monte Carlo or live mutation.

const ROOT: String = "res://content/domains/npc/definitions/"
const OUTCOME: Dictionary = CustomerParcelReactionRules.Outcome


#region Native capability and probability boundaries
func test_native_archetypes_have_one_valid_typed_parcel_capability() -> void:
	for key: String in ["brute", "chain_devil", "vampire", "fire_elemental"]:
		var archetype: DEF_NpcArchetype = load(ROOT + "def_npc_archetype_" + key + ".tres")
		assert_true(archetype.valid_rules(), key)
		var matches: int = 0
		for capability: DEF_NpcTrait in archetype.rules:
			if capability is DEF_NpcParcelReaction:
				matches += 1
				assert_same(capability, _rule(key))
		assert_eq(matches, 1, key)
		assert_true(_rule(key).valid_configuration())


func test_brute_checks_take_first_then_conditional_throw_only_after_not_taken() -> void:
	var rule: DEF_NpcParcelReaction = _rule("brute")
	for take_roll: float in [0.0, 0.249999, 0.25, 0.999999, 1.0]:
		for throw_roll: float in [0.0, 0.499999, 0.5, 1.0]:
			var expected: int = OUTCOME.REFUSE
			if take_roll < 0.25:
				expected = OUTCOME.KEEP
			elif throw_roll < 0.5:
				expected = OUTCOME.THROW_AT_PLAYER
			assert_eq(_choose(rule, take_roll, throw_roll), expected)
	# The conditional half of the remaining 75% is 37.5%, not an absolute 50% throw chance.
	assert_almost_eq(
		(1.0 - rule.take_probability) * rule.throw_after_not_taken_probability,
		0.375,
		0.000001,
	)


func test_chain_devil_never_keeps_and_throws_at_the_half_boundary() -> void:
	var rule: DEF_NpcParcelReaction = _rule("chain_devil")
	for take_roll: float in [0.0, 0.8, 1.0]:
		assert_eq(_choose(rule, take_roll, 0.499999), OUTCOME.THROW_AT_PLAYER)
		assert_eq(_choose(rule, take_roll, 0.5), OUTCOME.REFUSE)
		assert_eq(_choose(rule, take_roll, 1.0), OUTCOME.REFUSE)


func test_holy_contents_override_keep_or_player_throw_for_the_three_native_receivers() -> void:
	for key: String in ["brute", "chain_devil", "vampire"]:
		assert_eq(
			CustomerParcelReactionRules.choose(_rule(key), true, false, 0.0, 0.0),
			OUTCOME.THROW_ASIDE,
		)
	assert_eq(_choose(_rule("vampire"), 0.0, 0.0), OUTCOME.REFUSE)
	var ordinary_first: DEF_NpcParcelReaction = _rule("brute").duplicate() as DEF_NpcParcelReaction
	ordinary_first.holy_rejection_first = false
	assert_eq(
		CustomerParcelReactionRules.choose(ordinary_first, true, false, 0.0, 0.0),
		OUTCOME.KEEP,
	)
	assert_eq(
		CustomerParcelReactionRules.choose(ordinary_first, true, false, 0.8, 0.8),
		OUTCOME.THROW_ASIDE,
	)


func test_fire_uses_absolute_25_burn_15_damage_60_refusal_with_one_shared_roll() -> void:
	var rule: DEF_NpcParcelReaction = _rule("fire_elemental")
	for second_roll: float in [0.0, 1.0]:
		assert_eq(_choose(rule, 0.0, second_roll, true), OUTCOME.BURN)
		assert_eq(_choose(rule, 0.249999, second_roll, true), OUTCOME.BURN)
		assert_eq(_choose(rule, 0.25, second_roll, true), OUTCOME.DAMAGE)
		assert_eq(_choose(rule, 0.399999, second_roll, true), OUTCOME.DAMAGE)
		assert_eq(_choose(rule, 0.4, second_roll, true), OUTCOME.REFUSE)
		assert_eq(_choose(rule, 1.0, second_roll, true), OUTCOME.REFUSE)


func test_fire_ineligible_contents_have_only_the_absolute_15_percent_damage_interval() -> void:
	var rule: DEF_NpcParcelReaction = _rule("fire_elemental")
	assert_eq(_choose(rule, 0.0, 0.0), OUTCOME.DAMAGE)
	assert_eq(_choose(rule, 0.149999, 0.0), OUTCOME.DAMAGE)
	assert_eq(_choose(rule, 0.15, 0.0), OUTCOME.REFUSE)
	assert_eq(_choose(rule, 0.25, 0.0), OUTCOME.REFUSE)
	assert_eq(_choose(rule, 1.0, 0.0), OUTCOME.REFUSE)


func test_conditional_fire_tuning_is_explicit_and_does_not_change_native_absolute_default() -> void:
	var rule: DEF_NpcParcelReaction = _rule("fire_elemental").duplicate() as DEF_NpcParcelReaction
	rule.damage_after_not_burned = true
	assert_true(rule.valid_configuration())
	assert_eq(_choose(rule, 0.25, 0.149999, true), OUTCOME.DAMAGE)
	assert_eq(_choose(rule, 0.25, 0.15, true), OUTCOME.REFUSE)
	assert_eq(_choose(rule, 0.0, 0.0, true), OUTCOME.BURN)
	assert_false(_rule("fire_elemental").damage_after_not_burned)
#endregion


#region Invalid inputs and endpoint tuning
func test_zero_and_one_probabilities_handle_both_native_rng_endpoints() -> void:
	var rule: DEF_NpcParcelReaction = _rule("brute").duplicate() as DEF_NpcParcelReaction
	rule.take_probability = 1.0
	assert_eq(_choose(rule, 1.0, 1.0), OUTCOME.KEEP)
	rule.take_probability = 0.0
	rule.throw_after_not_taken_probability = 1.0
	assert_eq(_choose(rule, 0.0, 1.0), OUTCOME.THROW_AT_PLAYER)
	rule.throw_after_not_taken_probability = 0.0
	assert_eq(_choose(rule, 0.0, 0.0), OUTCOME.REFUSE)
	assert_eq(_choose(null, 0.0, 0.0), OUTCOME.REFUSE)


func test_nonfinite_out_of_range_or_incompatible_models_are_invalid_without_a_choice() -> void:
	var rule: DEF_NpcParcelReaction = _rule("brute").duplicate() as DEF_NpcParcelReaction
	for bad_roll: float in [NAN, INF, -0.001, 1.001]:
		assert_eq(_choose(rule, bad_roll, 0.0), OUTCOME.INVALID)
		assert_eq(_choose(rule, 0.0, bad_roll), OUTCOME.INVALID)
	rule.take_probability = NAN
	assert_false(rule.valid_configuration())
	assert_eq(_choose(rule, 0.0, 0.0), OUTCOME.INVALID)
	rule.take_probability = 0.25
	rule.burn_probability = 0.1
	assert_false(rule.valid_configuration())
	var fire: DEF_NpcParcelReaction = _rule("fire_elemental").duplicate() as DEF_NpcParcelReaction
	fire.burn_probability = 0.9
	assert_false(fire.valid_configuration())
	assert_eq(_choose(fire, 0.0, 0.0, true), OUTCOME.INVALID)
	fire.damage_after_not_burned = true
	assert_true(fire.valid_configuration())
	fire.kind = DEF_NpcTrait.Kind.FIRE_AURA
	assert_false(fire.valid_configuration())
#endregion


#region Authored policy fixture
func _rule(key: String) -> DEF_NpcParcelReaction:
	return load(ROOT + "def_npc_parcel_reaction_" + key + ".tres") as DEF_NpcParcelReaction


func _choose(
	rule: DEF_NpcParcelReaction,
	first: float,
	second: float,
	fire_destructible: bool = false,
) -> int:
	return CustomerParcelReactionRules.choose(rule, false, fire_destructible, first, second)
#endregion
