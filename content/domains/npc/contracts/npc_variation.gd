@tool
extends Resource
## Detached creation result; roster integration owns its one durable commit and subsequent reads.
class_name NpcVariation

const SAVE_FIELDS: Array[String] = [
	"archetype_key",
	"seed",
	"creation_day",
	"display_name",
	"dialogue_path",
	"optional_trait_keys",
	"move_speed_multiplier",
	"aggression_multiplier",
]

## Stable authored archetype key; matches the person's base definition.
@export var archetype_key: StringName = &""
## Generated seed derives from world/ID/day; fixed authored presets use zero.
@export var seed: int = 0
## Calendar day used for the named creation decision; never rerolled at scene load.
@export var creation_day: int = 1
## Authored name chosen once for this person.
@export var display_name: String = ""
## Selected authored dialogue path, or empty when the base dialogue owner applies.
@export var dialogue_path: String = ""
## Selected optional definition keys; mandatory traits stay in the immutable archetype.
@export var optional_trait_keys: Array[StringName] = []
## Rolled movement tuning multiplier, separate from body velocity and mutable shared Resources.
@export var move_speed_multiplier: float = 1.0
## Rolled social aggression tuning multiplier.
@export var aggression_multiplier: float = 1.0
