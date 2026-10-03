extends GameDefinition
## Authorable supernatural rule, its warning and its countermeasure.
class_name DEF_NpcTrait

enum Kind { GAZE_AVERSION, LIGHT_AVERSION, FIRE_AURA, DARK_PREDATOR, STRENGTH_TEST, PROVOCATEUR, RIDDLE }

## The behavior supplied by this trait.
@export var kind: Kind = Kind.GAZE_AVERSION
## Readable warning shown before escalation.
@export var warning_text: String = "Не испытывай моё терпение."
## Writer-facing explanation of the countermeasure.
@export var countermeasure: String = ""
## Sustained exposure required before the warning.
@export_range(0.1, 30.0) var warning_seconds: float = 1.5
## Additional exposure after a warning before a reaction.
@export_range(0.1, 60.0) var reaction_seconds: float = 3.0
## Trait range, including fire aura radius.
@export_range(0.2, 20.0) var radius: float = 3.0
## Light threshold used by light-sensitive and dark-hunting traits.
@export_range(0.0, 1.0) var light_threshold: float = 0.35
## Fire damage per second within the damaging area.
@export_range(0.0, 100.0) var damage_per_second: float = 8.0
## Traits that cannot coexist with this rule.
@export var incompatible: Array[Kind] = []
