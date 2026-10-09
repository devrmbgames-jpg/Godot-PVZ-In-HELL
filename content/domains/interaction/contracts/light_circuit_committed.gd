extends RefCounted
## Completed switch command fact; enabled is committed before any presentation callback.
class_name LightCircuitCommitted

## World channel for committed circuit state.
const EVENT: StringName = &"light_circuit_committed"
## Authored circuit identity at commit.
var circuit_id: StringName = &""
## Committed scalar switch state, separate from temporary flicker intent.
var enabled: bool = true
