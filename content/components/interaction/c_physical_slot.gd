extends Component
## One concrete small item per slot; simulation is suspended while attached.
class_name C_PhysicalSlot

@export var filter: DEF_AccessRequirement = null
@export_range(0.01, 100.0, 0.01) var maximum_mass: float = 8.0
@export var allow_hand_replacement: bool = false
