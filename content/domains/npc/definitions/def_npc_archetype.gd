@tool
extends DEF_NpcProfile
## Base archetype extends existing physical/social tuning; inherited rules are mandatory traits.
class_name DEF_NpcArchetype

enum CombatPreference {
	MELEE,
	RANGED,
	AVOID,
}

## At least two authored names; the selected value belongs to the durable person variation.
@export var name_variants: PackedStringArray = ["Житель", "Путник"]
## Optional authored dialogue paths; an empty pool retains the base dialogue owner.
@export var dialogue_variants: PackedStringArray = []
## Bounded weighted pool; duplicate keys and invalid entries are rejected before selection.
@export var optional_traits: Array[DEF_NpcTraitOption] = []
## Selection draws zero to this many optional traits, stopping when no compatible candidate remains.
@export_range(0, 8) var maximum_optional_traits: int = 2
## Inclusive authored speed multiplier interval; committed once and applied during construction.
@export var move_speed_variation: Vector2 = Vector2(0.9, 1.1)
## Inclusive authored aggression multiplier interval; committed once, never a shared Profile write.
@export var aggression_variation: Vector2 = Vector2(0.9, 1.1)
## Control speed scale during live combat, applied after the committed personal base speed.
@export_range(1.0, 4.0, 0.05) var aggressive_speed_multiplier: float = 1.0
## Commerce preference uses category bit values; empty means the ordinary available catalog.
@export var item_category_weights: Dictionary[int, float] = { }
## Preferred existing combat execution capability; native trees consume this authored choice.
@export var combat_preference: CombatPreference = CombatPreference.MELEE
## Intrinsic holy/unholy/blood receiver capabilities compiled through the existing Entity Traits.
@export_flags(
	"Holy vulnerable:1",
	"Unholy healing:2",
	"Vampire:4",
	"Unclean:8",
) \
		var receiver_traits: int = 0
## Intrinsic damage multipliers by DamageRequest.Type; immutable compiler inputs.
@export var damage_multipliers: Dictionary[int, float] = { }
## Authored presentation cue keys; gameplay decisions do not own audio/UI instances.
@export var presentation_cues: PackedStringArray = []


## Archetype validation includes mandatory/optional compatibility and bounded variation tuning.
func valid_rules() -> bool:
	return NpcVariationRules.valid_archetype(self)
