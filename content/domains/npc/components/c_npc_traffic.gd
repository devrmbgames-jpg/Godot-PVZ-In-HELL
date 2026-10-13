extends Component
## Transient local encounter state; S_NpcIntent is its sole scheduled writer.
class_name C_NpcTraffic

## Selected immutable authored policy, assigned during native capability construction.
@export var rule: DEF_NpcTraffic = null
## Seconds until the next threat for the live R_NpcBlocking encounter.
var threat_elapsed: float = 0.0
## Relative passing side retained until the encountered neighbour is cleared.
var passing_side: float = 1.0


#region Reset
## Clears only transient encounter state; the relationship owner releases its live binding.
func reset_transient_state() -> void:
	threat_elapsed = 0.0
	passing_side = 1.0
#endregion
