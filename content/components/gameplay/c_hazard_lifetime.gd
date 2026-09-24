extends Component
## Independent simulation lifetime; not tied to the origin Entity's presence.
class_name C_HazardLifetime

## Remaining seconds and reset policy initialized from the definition.
var remaining_seconds: float = 0.0
var persistent: bool = false
