extends Component
## Common lock and motion state. Concrete body/hinge integration belongs to R13.
class_name C_Openable

@export var locked: bool = false
@export var access: DEF_AccessRequirement = null
@export var motion: DEF_OpenableMotion = null
## Desired endpoint is intent, not a claim that a physical body has moved.
@export var requested_open: bool = false
## Written only from the physical controller's accepted position via report_fraction.
@export_range(0.0, 1.0) var actual_fraction: float = 0.0
