extends GameDefinition
## Stable address, portal, activity or route junction authored in district space.
class_name DEF_DistrictPlace

enum Kind { HOME, PORTAL, ACTIVITY, SHOP, JUNCTION }

## Placement category.
@export var kind: Kind = Kind.ACTIVITY
## Position relative to the district blockout root.
@export var position: Vector3 = Vector3.ZERO
## Connections in the district route graph.
@export var neighbours: PackedStringArray = []
## Base illumination independent of nearby lamps.
@export_range(0.0, 1.0) var ambient_light: float = 0.05
