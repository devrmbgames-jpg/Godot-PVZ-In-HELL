extends RefCounted
## Synchronous read-only presentation receipt; native sign ownership never stores customer state.
class_name NpcSignTextRequest

## Current deliberate communication; empty means no board, never a generic name/hint fallback.
var text: String = ""
## Optional stable source identity; a new request with identical text can replace the old one.
var intent_id: StringName = &""
