extends Component
## Generic challenge state. No timers, effects, AI or live Entity references.
class_name C_Challenge

enum Phase { INACTIVE, ARMED, ACTIVE, SUCCESS, FAILURE, CLEANUP }

@export var definition: DEF_Challenge = null
var phase: Phase = Phase.INACTIVE
var result: ChallengeResult.Type = ChallengeResult.Type.NONE
var condition_result: ChallengeResult.Type = ChallengeResult.Type.NONE
var consumed: bool = false
var elapsed: float = 0.0
var violation_elapsed: float = 0.0
var condition_violated: bool = false
var departure_requested: bool = false
var result_remaining: float = 0.0
var started_day: int = 0
var started_phase: C_DayCycle.Phase = C_DayCycle.Phase.DAY
var pending_result: ChallengeResolution = null
var consequences_applied: bool = false
## R17 consumes this typed request. It is not a second combat/AI owner.
var escalation_request: ChallengeResolution = null
