extends Component
class_name C_CustomerAgent

enum Phase { APPROACHING, WAITING, DIALOGUE, WAITING_FOR_PACKAGE, RECEIVING, OPTIONAL_FITTING, LEAVING, AGGRESSIVE, FINISHED }

var visit_id: StringName = &""
var phase: Phase = Phase.APPROACHING
var elapsed: float = 0.0
