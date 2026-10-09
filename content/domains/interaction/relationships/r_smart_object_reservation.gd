extends Component
## Authoritative actor to object reservation; no reverse occupancy authority exists.
class_name R_SmartObjectReservation

## Authored operation selected when the slot was acquired.
var affordance_id: StringName = &""
## Exclusive stable slot on the target object.
var slot_id: StringName = &""
## Transient world/object/component incarnation and acquisition sequence, never durable identity.
var token: StringName = &""
## Prevents a synchronous executor callback from repeating or cancelling the in-flight effect.
var executing: bool = false
## Derived engine lifetime callback, disconnected/cleared when the exact binding retires.
var retirement_callback: Callable = Callable()
