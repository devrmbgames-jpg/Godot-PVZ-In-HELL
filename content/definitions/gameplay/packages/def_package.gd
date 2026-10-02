extends GameDefinition
## Immutable shipment, physical handling and condition configuration.
class_name DEF_Package

enum Tag {
	NORMAL = 1,
	FRAGILE = 2,
	HEAVY = 4,
	LIQUID = 8,
}

## Stable diagnostic class encoded into the hidden package history ID.
## This does not replace gameplay tags or hazard prefabs.
enum HazardClass {
	NORMAL,
	FRAGILE,
	LIQUID,
	TOXIC,
	EXPLOSIVE,
	OTHER,
}

## Accounting value in whole monetary units; independent of trader resale price.
@export_range(0, 1000000000) var accounting_value: int = 100
## Market-comparable contents; no physical extraction mechanic in R20.
@export var content_item_key: StringName = &""
@export_range(1, 99) var content_quantity: int = 1
@export var shipment_number: String = ""
@export_multiline var description: String = ""
@export_multiline var comment: String = ""
## Stable recipient key; later resolved to an AssignedTo relationship with a Customer.
@export var recipient_id: StringName = &""
@export_flags("Normal:1", "Fragile:2", "Heavy:4", "Liquid:8") var tags: int = Tag.NORMAL
@export var history_hazard_class: HazardClass = HazardClass.NORMAL
@export_range(0.1, 100.0, 0.1, "or_greater") var mass_kg: float = 5.0
@export var throw_velocity: float = 10.0
@export var maximum_health: float = 100.0
## Remaining fraction of maximum HP at which ordinary damage becomes visible.
@export_range(0.0, 1.0, 0.05) var damaged_health_ratio: float = 0.60
@export_file_path("*.tscn") var scene_variants: Array[String] = []

## Generic impact profile, independent of descriptive tags and package lifecycle state.
@export var impact_profile: DEF_ImpactProfile = preload(
	"res://content/definitions/gameplay/def_impact_default.tres"
)

## Liquid-only continuous exposure; returning upright resets the timer completely.
@export_range(0.0, 180.0) var liquid_maximum_angle_degrees: float = 60.0
@export_range(0.0, 30.0) var liquid_tilt_seconds: float = 8.0
## One-time ordinary Health damage when leaking starts; zero keeps only condition effects.
@export_range(0.0, 10000.0) var liquid_tilt_damage: float = 10.0

## Optional autonomous hazard prefabs. Package does not classify/configure their behavior.
## Fires only on the first transition into C_PackageState.Damage.DAMAGED.
@export var hazard_on_damaged: PackedScene = null
## Fires on the terminal transition into C_PackageState.Damage.DESTROYED.
@export var hazard_on_destroyed: PackedScene = null
