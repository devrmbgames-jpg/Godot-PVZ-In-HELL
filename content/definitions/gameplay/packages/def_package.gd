@tool
extends GameDefinition
## Immutable shipment, physical handling and condition configuration.
class_name DEF_Package

## TODO перенести типы в отдельные definitions, как это сделано с аттрибутом.
## TODO Возможно еще придется создать отдельный настраиваемый источник урона, где будет
## прописана длительно, радиус, сила и т.д.
enum Hazard {
	NONE,
	TOXIC,
	EXPLOSIVE,
}

enum Tag {
	NORMAL = 1,
	FRAGILE = 2,
	HEAVY = 4,
	LIQUID = 8,
}

@export var shipment_number: String = ""
@export_multiline var description: String = ""
@export_multiline var comment: String = ""
## Stable recipient key; later resolved to an AssignedTo relationship with a Customer.
@export var recipient_id: StringName = &""
@export_flags("Normal:1", "Fragile:2", "Heavy:4", "Liquid:8") var tags: int = Tag.NORMAL
@export var hazard: Hazard = Hazard.NONE
@export_range(0.1, 100.0, 0.1, "or_greater") var mass_kg: float = 5.0
@export var throw_velocity: float = 10.0
@export var maximum_health: float = 100.0
## Remaining fraction of maximum HP at which ordinary damage becomes visible.
@export_range(0.0, 1.0, 0.05) var damaged_health_ratio: float = 0.60
@export_file_path("*.tscn") var scene_variants: Array[String] = []

## Generic impact profile, independent of descriptive tags and package lifecycle state.
@export var impact_profile: DEF_ImpactProfile = preload(
	"res://content/definitions/gameplay/impact_default.tres"
)

## Liquid-only continuous exposure; returning upright resets the timer completely.
@export_range(0.0, 180.0) var liquid_maximum_angle_degrees: float = 60.0
@export_range(0.0, 30.0) var liquid_tilt_seconds: float = 2.0
## One-time ordinary Health damage when leaking starts; zero keeps only condition effects.
@export_range(0.0, 10000.0) var liquid_tilt_damage: float = 10.0

## Optional reusable effect override; null uses the existing hazard enum's default prefab.
@export var hazard_effect: DEF_Hazard = null
## Zero selects enum defaults; explicitly opt into opening only when authored.
@export_flags("Destroyed:2", "Leaking:4", "Opened:8") var hazard_triggers: int = 0
