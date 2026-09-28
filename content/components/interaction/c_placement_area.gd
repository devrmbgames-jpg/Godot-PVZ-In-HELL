extends Component
## Assist volume, not an ownership container. Occupancy comes from physics queries.
class_name C_PlacementArea

@export var filter: DEF_AccessRequirement = null
@export var volume_size: Vector3 = Vector3.ONE
@export_flags_3d_physics var collision_mask: int = 29
@export_range(0.0, 0.1, 0.001) var clearance_margin: float = 0.002
