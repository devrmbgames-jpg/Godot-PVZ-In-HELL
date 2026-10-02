extends Component
class_name C_CustomerAgent

enum Phase { APPROACHING, WAITING, DIALOGUE, WAITING_FOR_PACKAGE, RECEIVING, OPTIONAL_FITTING, LEAVING, AGGRESSIVE, FINISHED, WAITING_FOR_DARKNESS }

var visit_id: StringName = &""
var phase: Phase = Phase.APPROACHING
var elapsed: float = 0.0
## Transient one-shot presentation guards for this physical appearance, not persistent visit facts.
var order_announced: bool = false
var dialogue_started: bool = false
