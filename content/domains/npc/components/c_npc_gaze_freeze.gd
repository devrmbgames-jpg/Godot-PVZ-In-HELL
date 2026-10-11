extends Component
## Derived observation state; S_NpcGazeFreeze owns observation, construction owns the rule.
class_name C_NpcGazeFreeze

## Optional selected immutable capability; null means this NPC has no observation constraint.
@export var rule: DEF_NpcGazeFreeze = null
## Latest actual camera/frustum/solid-LOS result, sampled before cadence every gameplay step.
var observed: bool = false
