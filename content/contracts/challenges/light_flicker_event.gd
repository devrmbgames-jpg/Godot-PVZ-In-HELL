extends RefCounted
## Presentation request; circuit.enabled remains the gameplay truth while lamps flicker.
class_name LightFlickerEvent

const EVENT: StringName = &"light_flickering"
const DEFAULT_INTERVAL_SECONDS: float = 0.15

enum Kind { START, STOP }

var kind: Kind = Kind.START
var request_id: StringName = &""
var circuit_id: StringName = &"warehouse"
var duration_seconds: float = 0.0
var interval_seconds: float = DEFAULT_INTERVAL_SECONDS
