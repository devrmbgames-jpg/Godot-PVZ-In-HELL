extends Resource
## Target-owned per-action state. No live actor/tool reference or UI authority.
class_name ProlongedInteractionProgress

enum Phase { IDLE, ADVANCING, READY, WAITING_FOR_RELEASE, COMPLETED }

@export var action_id: StringName = &""
@export_range(0.0, 1.0) var fraction: float = 0.0
@export var phase: Phase = Phase.IDLE
