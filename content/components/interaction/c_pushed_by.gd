extends Component
## Exclusive cart-to-actor Push relationship and reversible lifecycle bookkeeping.
class_name C_PushedBy

var capture_token: int = 0
var previous_can_sleep: bool = true
var lifecycle_applied: bool = false
