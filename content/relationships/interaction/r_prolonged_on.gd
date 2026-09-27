extends Component
## Actor -> affected target: one active prolonged session per actor/target.
## The lifecycle service owns creation, validation and capture-token release.
class_name R_ProlongedOn

var action: DEF_InteractionAction = null
var input_slot: DEF_InteractionAction.Slot = DEF_InteractionAction.Slot.USE
var capture_token: int = 0
