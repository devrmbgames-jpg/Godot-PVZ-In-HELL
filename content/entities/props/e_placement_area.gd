@tool
extends Entity
class_name E_PlacementArea

## Authored body origin; all actual collision shapes are validated around it.
@export var anchor: Node3D = null
