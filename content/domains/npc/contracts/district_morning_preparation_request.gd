extends RefCounted
## One future-morning preparation command; completion follows population and placement commits.
class_name DistrictMorningPreparationRequest

## Sole-handler preparation channel, distinct from a committed calendar phase.
const EVENT: StringName = &"district_morning_preparation_requested"
## Future gameplay day being prepared for capture.
var day_index: int = 0
## Calendar day at dispatch, used to reject a command superseded by a load or transition.
var context_day: int = 0
## Calendar phase at dispatch; preparing a future morning does not advance this phase.
var context_phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
## Receipt becomes terminal only after the handler's actual buffer commit.
var completed: bool = false
## True for a committed or already-prepared morning, including a level without a district.
var succeeded: bool = false
## Explicit terminal rejection reason; empty for successful preparation.
var rejection_reason: StringName = &""
