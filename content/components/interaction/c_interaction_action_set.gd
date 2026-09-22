extends Component
class_name C_InteractionActionSet

@export var actions: Array[InteractionAction] = []
## PRIMARY is hand-item use; the resolver maps either physical hand to this action.
## An occupied mapped hand reserves its input even without an available target.
@export_flags("Interact:1", "Use:2", "Primary:4", "Secondary:8") var reserved_slots: int = 0
