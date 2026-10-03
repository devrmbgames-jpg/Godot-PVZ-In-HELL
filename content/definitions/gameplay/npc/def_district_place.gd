extends GameDefinition
## Stable address, portal, activity or route junction authored in district space.
class_name DEF_DistrictPlace

enum Kind { HOME, PORTAL, ACTIVITY, SHOP, JUNCTION, COVER }
## Human-readable destination; stable key remains an internal binding.
@export var display_name: String = "Место района"

## Placement category.
@export var kind: Kind = Kind.ACTIVITY
## Position relative to the district blockout root.
@export var position: Vector3 = Vector3.ZERO
## Optional main-level marker supplies X/Z; position.y remains the authored ground height.
@export var anchor_path: NodePath = NodePath("")
## Connections in the district route graph.
@export var neighbours: PackedStringArray = []
## Base illumination independent of nearby lamps.
@export_range(0.0, 1.0) var ambient_light: float = 0.05
