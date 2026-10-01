extends Component
class_name C_Hunger

enum Tier { NORMAL, HUNGRY, STARVING }

@export var policy: DEF_HungerPolicy = null
@export var value: float = 0.0
var active_seconds: float = 0.0
