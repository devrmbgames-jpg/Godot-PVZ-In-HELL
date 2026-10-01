extends Component
class_name C_Combat

enum Phase { READY, WINDUP, ACTIVE, RECOVERY }

var phase: Phase = Phase.READY
var elapsed: float = 0.0
var strike: DEF_MeleeAttack = null
var hit_committed: bool = false
