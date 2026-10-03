extends GameDefinition
## Immutable identity, personality and capabilities; parcel policy belongs to each case.
class_name DEF_NpcProfile

enum Personality { AGGRESSIVE, BRAZEN, CHEERFUL, TIMID }

## Name used in dialogue and above the body.
@export var display_name: String = "Житель"
## Whether the person occupies a district home.
@export var resident: bool = true
## Whether this resident inherits the existing trading catalog.
@export var merchant: bool = false
## Recipient key used only when selecting recipients for new shipments.
@export var recipient_key: StringName = &""
## Primary social disposition.
@export var personality: Personality = Personality.CHEERFUL
## Weekly phase anchors.
@export var schedule: DEF_NpcSchedule = null
## At most two compatible supernatural rules.
@export var rules: Array[DEF_NpcTrait] = []
## Stable external scene for this person's physical body.
@export_file("*.tscn") var npc_scene_path: String = "res://content/entities/npc/district_npc.tscn"
## Readable personal interests for street conversations.
@export var interests: PackedStringArray = []
## Strong reaction to a validated offense.
@export_range(0.0, 1.0) var high_attack_probability: float = 0.75
## Flight tendency for aggressive and brazen people.
@export_range(0.0, 1.0) var low_flee_probability: float = 0.1
## Cheerful acceptance of a joke.
@export_range(0.0, 1.0) var joke_acceptance_probability: float = 0.9
## Timid flight probability under a serious threat.
@export_range(0.0, 1.0) var timid_flee_probability: float = 0.8
## Timid attack probability under a serious threat.
@export_range(0.0, 1.0) var timid_attack_probability: float = 0.05
## Ground locomotion speed in meters per second.
@export_range(0.1, 8.0) var move_speed: float = 1.8
## Perception range in ordinary light.
@export_range(1.0, 50.0) var vision_range: float = 16.0
## Horizontal vision cone in degrees.
@export_range(30.0, 180.0) var vision_angle: float = 110.0
## Range multiplier in darkness for ordinary eyes.
@export_range(0.0, 1.0) var dark_vision_fraction: float = 0.15
## Search duration after the last confirmed sighting.
@export_range(1.0, 120.0) var search_seconds: float = 12.0
## Lowest remaining HP fraction accepted during a risky pursuit.
@export_range(0.0, 1.0) var pursuit_health_reserve: float = 0.35
## Whether this profile may initiate a bounded ambient attack.
@export var initiates_conflicts: bool = false
## Base color differentiating people in the blockout.
@export var body_color: Color = Color(0.65, 0.45, 0.35)

#region Trait queries
## Finds a supernatural rule without allocating a new collection.
func rule_for(kind: DEF_NpcTrait.Kind) -> DEF_NpcTrait:
	for rule: DEF_NpcTrait in rules:
		if rule != null and rule.kind == kind:
			return rule
	return null

## Checks the authored combination before spawning.
func valid_rules() -> bool:
	if rules.size() > 2:
		return false
	var seen: Array[int] = []
	for rule: DEF_NpcTrait in rules:
		if rule == null or seen.has(rule.kind):
			return false
		for other: DEF_NpcTrait in rules:
			if other != null and other != rule and rule.incompatible.has(other.kind):
				return false
		seen.append(rule.kind)
	return schedule != null
#endregion
