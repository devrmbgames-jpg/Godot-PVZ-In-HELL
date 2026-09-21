@tool
extends GameDefinition
class_name DEF_Package

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
