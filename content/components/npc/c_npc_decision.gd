extends Component
## Transient single-owner decision state; no stored physics transform or target reference.
class_name C_NpcDecision

enum Owner { EMERGENCY, COMBAT, SERVICE, SCHEDULE, IDLE, NONE }

## Current branch permitted to issue movement and actions.
var intent_owner: Owner = Owner.NONE
## Debug-facing active behavior label.
var active_behavior: String = ""
## Elapsed time toward the next bounded AI update.
var update_elapsed: float = 0.0
## Time spent on an unreachable destination.
var blocked_elapsed: float = 0.0
