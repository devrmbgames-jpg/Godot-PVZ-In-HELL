extends Component
class_name C_Receiving

var last_started_day: int = 0
var pending: Array[DeliveryBatch] = []
var delivered_counts: Dictionary[int, int] = { }
var blocked: bool = false
var retry_remaining: float = 0.0
var last_spawn_tick: int = -1
