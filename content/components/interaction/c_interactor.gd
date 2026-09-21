extends Component
class_name C_Interactor

@export_flags_3d_physics var collision_mask: int = 15
@export_range(0.1, 10.0, 0.1, "or_greater") var interaction_distance: float = 3.0

## Selection only; ownership is a C_HeldBy relationship.
var target: Entity = null
## Read-only presentation snapshot, written at the gameplay command boundary.
var prompt_text: String = ""
var last_action_tick: int = -1
