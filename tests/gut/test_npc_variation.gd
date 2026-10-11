extends GutTest
## Detached deterministic choices, compatibility, shared-resource isolation and closed record codec.

const WORLD_SEED: int = 91234
const NPC_ID: StringName = &"npc/1"

var _archetype: DEF_NpcArchetype


func before_each() -> void:
	_archetype = DEF_NpcArchetype.new()
	_archetype.key = &"archetype/test"
	_archetype.schedule = DEF_NpcSchedule.new()
	_archetype.name_variants = ["Тихон", "Мирон"]
	_archetype.dialogue_variants = [
		"res://content/domains/npc/dialogue/npc_street.dialogue",
		"res://content/domains/customers/dialogue/customer_service.dialogue",
	]
	_archetype.rules = [_trait(&"gaze", DEF_NpcTrait.Kind.GAZE_AVERSION)]
	_archetype.maximum_optional_traits = 3
	var hidden: DEF_NpcTrait = _trait(&"hidden", DEF_NpcTrait.Kind.LIGHT_AVERSION)
	hidden.incompatible_keys = [&"gaze"]
	var fire: DEF_NpcTrait = _trait(&"fire", DEF_NpcTrait.Kind.FIRE_AURA)
	fire.incompatible_keys = [&"strength"]
	_archetype.optional_traits = [
		_option(hidden),
		_option(fire),
		_option(_trait(&"riddle", DEF_NpcTrait.Kind.RIDDLE)),
		_option(_trait(&"strength", DEF_NpcTrait.Kind.STRENGTH_TEST)),
	]


func _trait(key: StringName, kind: DEF_NpcTrait.Kind) -> DEF_NpcTrait:
	var rule: DEF_NpcTrait = DEF_NpcTrait.new()
	rule.key = key
	rule.kind = kind
	return rule


func _option(rule: DEF_NpcTrait, weight: float = 1.0) -> DEF_NpcTraitOption:
	var option: DEF_NpcTraitOption = DEF_NpcTraitOption.new()
	option.rule = rule
	option.weight = weight
	return option


func _create(npc_id: StringName = NPC_ID) -> NpcVariation:
	return NpcVariationRules.create(_archetype, WORLD_SEED, npc_id, 1)


func test_creation_is_repeatable_order_independent_and_does_not_mutate_archetype() -> void:
	assert_true(_archetype.valid_rules())
	var original_rules: Array[DEF_NpcTrait] = _archetype.rules.duplicate()
	var original_options: Array[DEF_NpcTraitOption] = _archetype.optional_traits.duplicate()
	var first: NpcVariation = _create()
	var encoded: Dictionary = SaveDataCodec.encode(first) as Dictionary
	var second: NpcVariation = _create()
	assert_ne(first, second, "Preview results have separate ownership")
	assert_eq(SaveDataCodec.encode(second), encoded)
	_archetype.optional_traits.reverse()
	assert_eq(SaveDataCodec.encode(_create()), encoded)
	assert_eq(_archetype.rules, original_rules)
	_archetype.optional_traits.reverse()
	assert_eq(_archetype.optional_traits, original_options)
	assert_eq(_archetype.display_name, "Житель")
	assert_eq(_archetype.move_speed, 1.8)
	assert_true(NpcVariationRules.valid_variation(_archetype, first, WORLD_SEED, NPC_ID))
	assert_false(NpcVariationRules.valid_variation(_archetype, first, WORLD_SEED + 1, NPC_ID))
	assert_false(NpcVariationRules.valid_variation(_archetype, first, WORLD_SEED, &"npc/2"))


func test_many_persons_select_only_compatible_bounded_traits_and_distinct_names() -> void:
	var names: Dictionary[String, bool] = { }
	var seeds: Dictionary[int, bool] = { }
	var optional_choices: Dictionary[String, bool] = { }
	for index: int in range(1, 65):
		var npc_id: StringName = StringName("npc/%d" % index)
		var variation: NpcVariation = _create(npc_id)
		assert_true(NpcVariationRules.valid_variation(_archetype, variation, WORLD_SEED, npc_id))
		assert_false(variation.optional_trait_keys.has(&"hidden"))
		assert_false(
			variation.optional_trait_keys.has(&"fire")
			and variation.optional_trait_keys.has(&"strength")
		)
		var selected: Array[DEF_NpcTrait] = NpcVariationRules.traits_for(_archetype, variation)
		assert_true(selected.has(_archetype.rules[0]), "Mandatory rule cannot be omitted")
		assert_lte(selected.size(), 1 + _archetype.maximum_optional_traits)
		names[variation.display_name] = true
		seeds[variation.seed] = true
		optional_choices[str(variation.optional_trait_keys)] = true
	assert_eq(names.size(), 2)
	assert_eq(seeds.size(), 64)
	assert_gt(optional_choices.size(), 2)


func test_weighted_selection_favors_authored_weight_without_global_rng() -> void:
	_archetype.rules.clear()
	_archetype.maximum_optional_traits = 1
	_archetype.optional_traits = [
		_option(_trait(&"heavy", DEF_NpcTrait.Kind.RIDDLE), 1000.0),
		_option(_trait(&"light", DEF_NpcTrait.Kind.STRENGTH_TEST), 1.0),
	]
	var heavy: int = 0
	var light: int = 0
	for index: int in range(1, 129):
		var variation: NpcVariation = _create(StringName("npc/%d" % index))
		heavy += 1 if variation.optional_trait_keys.has(&"heavy") else 0
		light += 1 if variation.optional_trait_keys.has(&"light") else 0
	assert_gt(heavy, light)
	assert_gt(heavy, 0)


func test_invalid_definitions_reject_before_creation_without_mutating_shared_inputs() -> void:
	_archetype.optional_traits[0].weight = NAN
	assert_null(_create())
	_archetype.optional_traits[0].weight = 1.0
	_archetype.optional_traits.append(_archetype.optional_traits[0])
	assert_null(_create())
	_archetype.optional_traits.pop_back()
	_archetype.rules.append(_trait(&"same_behavior", DEF_NpcTrait.Kind.GAZE_AVERSION))
	assert_null(_create())
	_archetype.rules.pop_back()
	_archetype.maximum_optional_traits = 9
	assert_null(_create())
	_archetype.maximum_optional_traits = 3
	_archetype.move_speed_variation = Vector2(1.0, INF)
	assert_null(_create())
	_archetype.move_speed_variation = Vector2(1.2, 0.8)
	assert_null(_create())
	_archetype.move_speed_variation = Vector2.ONE
	_archetype.name_variants = ["Тихон", "Тихон"]
	assert_null(_create())
	_archetype.name_variants = ["Тихон", "Мирон"]
	_archetype.dialogue_variants = ["res://" + "missing.dialogue"]
	assert_null(_create())
	_archetype.dialogue_variants.clear()
	_archetype.receiver_traits = 16
	assert_null(_create())
	_archetype.receiver_traits = 0
	_archetype.item_category_weights = { 3: 1.0 }
	assert_null(_create())
	_archetype.item_category_weights.clear()
	_archetype.damage_multipliers = { DamageRequest.Type.FIRE: -1.0 }
	assert_null(_create())


func test_closed_codec_roundtrip_preserves_choices_and_rejects_missing_or_extra_fields() -> void:
	var variation: NpcVariation = _create()
	var encoded: Dictionary = SaveDataCodec.encode(variation) as Dictionary
	var restored: NpcVariation = SaveDataCodec.decode(encoded) as NpcVariation
	assert_not_null(restored)
	assert_ne(restored, variation)
	assert_eq(SaveDataCodec.encode(restored), encoded)
	assert_true(NpcVariationRules.valid_variation(_archetype, restored, WORLD_SEED, NPC_ID))
	var fields: Dictionary = encoded.fields as Dictionary
	fields.erase("seed")
	assert_null(SaveDataCodec.decode(encoded))
	encoded = SaveDataCodec.encode(variation) as Dictionary
	(encoded.fields as Dictionary)["extra"] = 1
	assert_null(SaveDataCodec.decode(encoded))
	assert_eq(SaveDataCodec.encode(variation), SaveDataCodec.encode(_create()))


func test_invalid_committed_choices_reject_without_rerolling() -> void:
	var variation: NpcVariation = _create()
	variation.optional_trait_keys = [&"hidden"]
	assert_false(NpcVariationRules.valid_variation(_archetype, variation, WORLD_SEED, NPC_ID))
	variation.optional_trait_keys = [&"riddle", &"riddle"]
	assert_false(NpcVariationRules.valid_variation(_archetype, variation, WORLD_SEED, NPC_ID))
	variation.optional_trait_keys = [&"missing"]
	assert_false(NpcVariationRules.valid_variation(_archetype, variation, WORLD_SEED, NPC_ID))
	variation.optional_trait_keys.clear()
	variation.move_speed_multiplier = NAN
	assert_false(NpcVariationRules.valid_variation(_archetype, variation, WORLD_SEED, NPC_ID))
	variation.move_speed_multiplier = 1.0
	variation.display_name = "Неавторское имя"
	assert_false(NpcVariationRules.valid_variation(_archetype, variation, WORLD_SEED, NPC_ID))
	assert_eq(
		variation.display_name,
		"Неавторское имя",
		"Validation cannot replace a failed choice",
	)
