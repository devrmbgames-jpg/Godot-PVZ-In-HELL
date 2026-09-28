@tool
extends Entity
class_name E_PhysicalSlot

@export var anchor: Node3D = null
@export var driver: RemoteTransform3D = null


func on_ready() -> void:
	if Engine.is_editor_hint():
		return
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Entity:
			add_relationship(Relationship.new(R_SlotMountedOn.new(), ancestor as Entity))
			return
		ancestor = ancestor.get_parent()
