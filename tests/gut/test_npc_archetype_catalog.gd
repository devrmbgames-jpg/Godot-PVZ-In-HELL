extends GutTest
## Native authored archetype contracts; runtime behavior remains in the integration suites.

const ARCHETYPES: Array[DEF_NpcArchetype] = [
	preload("res://content/domains/npc/definitions/def_npc_archetype_shy.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_weeping_angel.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_night_hunter.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_hag.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_brute.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_fire_elemental.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_lost.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_chain_devil.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_creepy.tres"),
	preload("res://content/domains/npc/definitions/def_npc_archetype_vampire.tres"),
]
const PLACEHOLDER_NAMES: Array[Array] = [
	["Тихон", "Мирон"],
	["Сераф", "Азариэль"],
	["Морок", "Нокт"],
	["Морана", "Аграфена"],
	["Гром", "Бран"],
	["Пирос", "Углик"],
	["Лука", "Ян"],
	["Азгар", "Мальх"],
	["Шорох", "Хрип"],
	["Северин", "Владен"],
]
const WORLD_SEED: int = 42518


func test_native_archetypes_have_required_names_and_valid_isolated_creation() -> void:
	var keys: Dictionary[StringName, bool] = { }
	for index: int in ARCHETYPES.size():
		var archetype: DEF_NpcArchetype = ARCHETYPES[index]
		assert_false(keys.has(archetype.key), "Each authored archetype has a distinct stable key")
		keys[archetype.key] = true
		assert_true(archetype.valid_rules(), archetype.resource_path)
		assert_eq(archetype.name_variants, PackedStringArray(PLACEHOLDER_NAMES[index]))
		assert_true(ResourceLoader.exists(archetype.npc_scene_path))
		assert_eq(
			archetype.schedule.location_for(1, C_DayCycle.Phase.MORNING),
			DEF_NpcSchedule.Location.STREET,
		)

		var original_speed: float = archetype.move_speed
		var original_rules: Array[DEF_NpcTrait] = archetype.rules.duplicate()
		var original_options: Array[DEF_NpcTraitOption] = archetype.optional_traits.duplicate()
		for person_number: int in range(1, 17):
			var npc_id: StringName = StringName("npc/%d" % person_number)
			var variation: NpcVariation = NpcVariationRules.create(archetype, WORLD_SEED, npc_id, 1)
			assert_not_null(variation)
			assert_true(NpcVariationRules.valid_variation(archetype, variation, WORLD_SEED, npc_id))
			var encoded: Dictionary = SaveDataCodec.encode(variation) as Dictionary
			var restored: NpcVariation = SaveDataCodec.decode(encoded) as NpcVariation
			assert_not_null(restored)
			assert_eq(SaveDataCodec.encode(restored), encoded)
			assert_eq(
				SaveDataCodec.encode(NpcVariationRules.create(archetype, WORLD_SEED, npc_id, 1)),
				encoded,
			)
		assert_eq(archetype.move_speed, original_speed, "Creation cannot edit authoring")
		assert_eq(archetype.rules, original_rules)
		assert_eq(archetype.optional_traits, original_options)
		assert_eq(archetype.name_variants, PackedStringArray(PLACEHOLDER_NAMES[index]))
	assert_eq(keys.size(), 10)


func test_existing_behavior_capabilities_are_authored_on_the_intended_archetypes() -> void:
	assert_not_null(ARCHETYPES[0].rule_for(DEF_NpcTrait.Kind.GAZE_AVERSION))
	assert_not_null(ARCHETYPES[2].rule_for(DEF_NpcTrait.Kind.DARK_PREDATOR))
	assert_not_null(ARCHETYPES[2].rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION))
	assert_not_null(ARCHETYPES[3].rule_for(DEF_NpcTrait.Kind.RIDDLE))
	assert_not_null(ARCHETYPES[4].rule_for(DEF_NpcTrait.Kind.STRENGTH_TEST))
	assert_not_null(ARCHETYPES[5].rule_for(DEF_NpcTrait.Kind.FIRE_AURA))
	assert_true(ARCHETYPES[6].rules.is_empty(), "Lost is the neutral supernatural baseline")
	assert_eq(ARCHETYPES[3].combat_preference, DEF_NpcArchetype.CombatPreference.RANGED)
	assert_false(ARCHETYPES[3].ranged_attacks.is_empty())


func test_intrinsic_receiver_and_damage_contracts_use_existing_semantic_types() -> void:
	var angel: DEF_NpcArchetype = ARCHETYPES[1]
	for damage_type: int in range(DamageRequest.Type.GENERIC, DamageRequest.Type.UNHOLY + 1):
		assert_true(angel.damage_multipliers.has(damage_type))
		assert_eq(
			angel.damage_multipliers[damage_type],
			1.0 if damage_type == DamageRequest.Type.HOLY else 0.0,
		)
	for index: int in [5, 7]:
		assert_eq(ARCHETYPES[index].damage_multipliers[DamageRequest.Type.FIRE], 0.0)
	var vampire: DEF_NpcArchetype = ARCHETYPES[9]
	assert_true(vampire.receiver_traits & C_ReceiverTraits.Trait.VAMPIRE != 0)
	assert_true(vampire.receiver_traits & C_ReceiverTraits.Trait.HOLY_VULNERABLE != 0)
	assert_true(vampire.receiver_traits & C_ReceiverTraits.Trait.UNHOLY_HEALING != 0)
	assert_true(vampire.receiver_traits & C_ReceiverTraits.Trait.UNCLEAN != 0)


func test_order_preferences_are_category_data_and_neutral_accepts_available_catalog() -> void:
	var clothing: int = DEF_InventoryItem.Category.CLOTHING
	var weapon: int = DEF_InventoryItem.Category.WEAPON
	var toy: int = DEF_InventoryItem.Category.TOY
	assert_gt(ARCHETYPES[0].item_category_weights.get(clothing, 0.0), 0.0)
	assert_gt(
		ARCHETYPES[1].item_category_weights.get(DEF_InventoryItem.Category.ARTIFACT, 0.0),
		0.0,
	)
	assert_gt(ARCHETYPES[2].item_category_weights.get(weapon, 0.0), 0.0)
	assert_gt(ARCHETYPES[2].item_category_weights.get(clothing, 0.0), 0.0)
	assert_gt(ARCHETYPES[3].item_category_weights.get(DEF_InventoryItem.Category.REAGENT, 0.0), 0.0)
	assert_gt(
		ARCHETYPES[3].item_category_weights.get(DEF_InventoryItem.Category.ARTIFACT, 0.0),
		0.0,
	)
	assert_gt(ARCHETYPES[4].item_category_weights.get(toy, 0.0), 0.0)
	assert_gt(ARCHETYPES[4].item_category_weights[weapon], ARCHETYPES[4].item_category_weights[toy])
	assert_gt(ARCHETYPES[5].item_category_weights.get(DEF_InventoryItem.Category.REAGENT, 0.0), 0.0)
	assert_true(ARCHETYPES[6].item_category_weights.is_empty())
	assert_gt(ARCHETYPES[7].item_category_weights.get(weapon, 0.0), 0.0)
	assert_gt(
		ARCHETYPES[7].item_category_weights.get(DEF_InventoryItem.Category.ARTIFACT, 0.0),
		0.0,
	)
	assert_lt(
		ARCHETYPES[7].item_category_weights[clothing],
		ARCHETYPES[7].item_category_weights[weapon],
	)
