extends Component
class_name C_InteractionActions

@export var actions: Array[InteractionAction] = []
## Held tools reserve their buttons even when no valid action target is present.
## Scanner: Primary (4); Marker: Secondary (8). Alt bypasses tool reservations.
@export_flags("Interact:1", "Use:2", "Primary:4", "Secondary:8") var reserved_slots: int = 0
