@tool
extends Entity
## Авторский физический слот с точкой крепления; связывается с ближайшей родительской Entity.
class_name E_PhysicalSlot

## Авторская точка, к которой крепится физический предмет.
@export var anchor: Node3D = null
## RemoteTransform3D, передающий положение закреплённому и временно замороженному предмету.
@export var driver: RemoteTransform3D = null


## В игре создаёт R_SlotMountedOn к ближайшей родительской Entity.
func on_ready() -> void:
	if Engine.is_editor_hint():
		return

	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Entity:
			add_relationship(Relationship.new(R_SlotMountedOn.new(), ancestor as Entity))
			return

		ancestor = ancestor.get_parent()
