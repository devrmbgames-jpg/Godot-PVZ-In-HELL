extends Component
class_name C_CombatProjectile

var velocity: Vector3 = Vector3.ZERO
var remaining_seconds: float = 0.0
var damage: float = 0.0
var collision_mask: int = 31
var attribution: CombatContext = null
var instigator_id: String = ""
