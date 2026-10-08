extends RefCounted
## Committed perception step; synchronous role reactions precede the native BT decision.
class_name NpcDecisionReady

## Due-step fact channel, independent of a visit or service action.
const EVENT: StringName = &"npc_decision_ready"
## Accumulated seconds consumed by this decision, rather than the render-frame delta.
var delta_seconds: float = 0.0

#region Construction
## Captures the committed perception interval without retaining the mutable decision.
func _init(elapsed_seconds: float = 0.0) -> void:
	delta_seconds = elapsed_seconds
#endregion
