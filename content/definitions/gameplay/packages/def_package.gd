@tool
extends GameDefinition
## Immutable shipment, physical handling and condition configuration.
class_name DEF_Package

## TODO перенести типы в отдельные definitions, как это сделано с аттрибутом.
## TODO Возможно еще придется создать отдельный настраиваемый источник урона, где будет прописана длительно, радиус, сила и т.д.
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
@export_range(0.0, 1.0) var carry_speed: float = 1.0
@export_range(0.0, 1.0) var carry_acceleration: float = 1.0
@export var throw_velocity: float = 10.0
@export var maximum_health: float = 100.0

## Generic impact profile, independent of descriptive tags and package lifecycle state.
@export var impact_profile: DEF_ImpactProfile = preload(
	"res://content/definitions/gameplay/impact_default.tres"
)
