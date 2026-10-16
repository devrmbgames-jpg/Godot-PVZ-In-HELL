extends RefCounted
## Bounded archetype validation and deterministic detached creation; no global RNG or roster writes.
class_name NpcVariationRules

const MAXIMUM_TRAITS: int = 8
const MAXIMUM_POOL: int = 32
const MINIMUM_MULTIPLIER: float = 0.25
const MAXIMUM_MULTIPLIER: float = 4.0
const RECEIVER_MASK: int = (
	C_ReceiverTraits.Trait.HOLY_VULNERABLE | C_ReceiverTraits.Trait.UNHOLY_HEALING
	| C_ReceiverTraits.Trait.VAMPIRE | C_ReceiverTraits.Trait.UNCLEAN
)
const CREATION_DECISION: String = "npc/archetype_creation"


#region Authored validation
static func valid_archetype(archetype: DEF_NpcArchetype) -> bool:
	if (
		archetype == null or archetype.key.is_empty() or archetype.schedule == null
		or archetype.name_variants.size() < 2 or archetype.optional_traits.size() > MAXIMUM_POOL
		or archetype.maximum_optional_traits < 0
		or archetype.rules.size() + archetype.maximum_optional_traits > MAXIMUM_TRAITS
		or not _valid_interval(archetype.move_speed_variation)
		or not _valid_interval(archetype.aggression_variation)
		or archetype.receiver_traits < 0 or not is_finite(archetype.aggressive_speed_multiplier)
		or archetype.aggressive_speed_multiplier < 1.0
		or archetype.aggressive_speed_multiplier > MAXIMUM_MULTIPLIER
		or archetype.receiver_traits & ~RECEIVER_MASK != 0
		or archetype.combat_preference < DEF_NpcArchetype.CombatPreference.MELEE
		or archetype.combat_preference > DEF_NpcArchetype.CombatPreference.AVOID
	):
		return false
	var names: Dictionary[String, bool] = { }
	for candidate: String in archetype.name_variants:
		if candidate.strip_edges().is_empty() or names.has(candidate):
			return false
		names[candidate] = true
	var keys: Dictionary[StringName, bool] = { }
	var mandatory: Array[DEF_NpcTrait] = []
	for rule: DEF_NpcTrait in archetype.rules:
		if not _valid_trait(rule) or not _compatible_with(rule, mandatory):
			return false
		keys[rule.key] = true
		mandatory.append(rule)
	for option: DEF_NpcTraitOption in archetype.optional_traits:
		if (
			option == null or not _valid_trait(option.rule) or keys.has(option.rule.key)
			or not is_finite(option.weight) or option.weight <= 0.0 or option.weight > 1000.0
		):
			return false
		keys[option.rule.key] = true
	for category: int in archetype.item_category_weights:
		var weight: float = archetype.item_category_weights[category]
		if (
			category <= 0 or category > DEF_InventoryItem.Category.VALUABLE
			or category & (category - 1) != 0 or not is_finite(weight) or weight < 0.0
		):
			return false
	for damage_type: int in archetype.damage_multipliers:
		var multiplier: float = archetype.damage_multipliers[damage_type]
		if (
			damage_type < DamageRequest.Type.GENERIC or damage_type > DamageRequest.Type.UNHOLY
			or not is_finite(multiplier) or multiplier < 0.0
		):
			return false
	var paths: Dictionary[String, bool] = { }
	for path: String in archetype.dialogue_variants:
		if (
			not path.begins_with("res://") or not path.ends_with(".dialogue")
			or paths.has(path) or not ResourceLoader.exists(path)
		):
			return false
		paths[path] = true
	return true


static func _valid_interval(interval: Vector2) -> bool:
	return (
		interval.is_finite() and interval.x >= MINIMUM_MULTIPLIER
		and interval.x <= interval.y and interval.y <= MAXIMUM_MULTIPLIER
	)


static func _valid_trait(rule: DEF_NpcTrait) -> bool:
	return (rule != null and not rule.key.is_empty() and rule.valid_configuration())


static func _compatible_with(candidate: DEF_NpcTrait, selected: Array[DEF_NpcTrait]) -> bool:
	for rule: DEF_NpcTrait in selected:
		if (
			candidate.key == rule.key
			or (
				candidate.kind == rule.kind
				and (
					candidate.kind != DEF_NpcTrait.Kind.CAPABILITY
					or candidate.get_script() == rule.get_script()
				)
			)
			or candidate.incompatible.has(rule.kind)
			or rule.incompatible.has(candidate.kind) or candidate.incompatible_keys.has(rule.key)
			or rule.incompatible_keys.has(candidate.key)
		):
			return false
	return true
#endregion


#region Detached creation and durable validation
## Resolves already validated selected keys; returned definitions remain immutable authoring inputs.
static func traits_for(base: DEF_NpcArchetype, variation: NpcVariation) -> Array[DEF_NpcTrait]:
	var selected: Array[DEF_NpcTrait] = base.rules.duplicate()
	for trait_key: StringName in variation.optional_trait_keys:
		for option: DEF_NpcTraitOption in base.optional_traits:
			if option.rule.key == trait_key:
				selected.append(option.rule)
				break
	return selected


## Produces a fresh deterministic result; callers commit it after successful spawn preflight.
static func create(
	archetype: DEF_NpcArchetype,
	world_seed: int,
	npc_id: StringName,
	creation_day: int,
) -> NpcVariation:
	if npc_id.is_empty() or creation_day < 1 or not valid_archetype(archetype):
		return null
	var variation: NpcVariation = NpcVariation.new()
	variation.archetype_key = archetype.key
	variation.creation_day = creation_day
	variation.seed = DecisionRandomRules.seed_for(
		world_seed,
		String(npc_id),
		creation_day,
		CREATION_DECISION,
	)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = variation.seed
	variation.display_name = archetype.name_variants[
		random.randi_range(0, archetype.name_variants.size() - 1)
	]
	if not archetype.dialogue_variants.is_empty():
		variation.dialogue_path = archetype.dialogue_variants[
			random.randi_range(0, archetype.dialogue_variants.size() - 1)
		]
	var selected: Array[DEF_NpcTrait] = archetype.rules.duplicate()
	var target: int = random.randi_range(0, archetype.maximum_optional_traits)
	for index: int in target:
		var options: Array[DEF_NpcTraitOption] = []
		for option: DEF_NpcTraitOption in archetype.optional_traits:
			if _compatible_with(option.rule, selected):
				options.append(option)
		if options.is_empty():
			break
		# Canonical keys exclude editor array order from weighted selection.
		options.sort_custom(
			func(a: DEF_NpcTraitOption, b: DEF_NpcTraitOption) -> bool:
				return String(a.rule.key) < String(b.rule.key),
		)
		var total: float = 0.0
		for option: DEF_NpcTraitOption in options:
			total += option.weight
		var roll: float = random.randf() * total
		var choice: DEF_NpcTraitOption = options.back()
		for option: DEF_NpcTraitOption in options:
			roll -= option.weight
			if roll < 0.0:
				choice = option
				break
		selected.append(choice.rule)
		variation.optional_trait_keys.append(choice.rule.key)
	variation.move_speed_multiplier = random.randf_range(
		archetype.move_speed_variation.x,
		archetype.move_speed_variation.y,
	)
	variation.aggression_multiplier = random.randf_range(
		archetype.aggression_variation.x,
		archetype.aggression_variation.y,
	)
	return variation


## Validates committed values without recomputing random choices or altering authored Resources.
static func valid_variation(
	archetype: DEF_NpcArchetype,
	variation: NpcVariation,
	world_seed: int,
	npc_id: StringName,
) -> bool:
	if (
		not valid_selection(archetype, variation) or npc_id.is_empty()
		or not archetype.name_variants.has(variation.display_name)
	):
		return false
	return variation.seed == DecisionRandomRules.seed_for(
		world_seed,
		String(npc_id),
		variation.creation_day,
		CREATION_DECISION,
	)


## Проверяет совместимость фиксированного набора; авторское имя не обязано входить в RNG-пул.
static func valid_selection(archetype: DEF_NpcArchetype, variation: NpcVariation) -> bool:
	if (
		not valid_archetype(archetype) or variation == null
		or variation.archetype_key != archetype.key or variation.seed < 0
		or variation.creation_day < 1 or variation.display_name.strip_edges().is_empty()
		or variation.optional_trait_keys.size() > archetype.maximum_optional_traits
		or not is_finite(variation.move_speed_multiplier)
		or variation.move_speed_multiplier < archetype.move_speed_variation.x
		or variation.move_speed_multiplier > archetype.move_speed_variation.y
		or not is_finite(variation.aggression_multiplier)
		or variation.aggression_multiplier < archetype.aggression_variation.x
		or variation.aggression_multiplier > archetype.aggression_variation.y
	):
		return false
	if archetype.dialogue_variants.is_empty():
		if not variation.dialogue_path.is_empty():
			return false
	elif not archetype.dialogue_variants.has(variation.dialogue_path):
		return false
	var selected: Array[DEF_NpcTrait] = archetype.rules.duplicate()
	for trait_key: StringName in variation.optional_trait_keys:
		var candidate: DEF_NpcTrait = null
		for option: DEF_NpcTraitOption in archetype.optional_traits:
			if option.rule.key == trait_key:
				candidate = option.rule
				break
		if candidate == null or not _compatible_with(candidate, selected):
			return false
		selected.append(candidate)
	return true
#endregion
