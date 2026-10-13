extends RefCounted
## Synchronous read-only presentation receipt; native sign ownership never stores customer state.
class_name NpcSignTextRequest

## Default native message, optionally replaced by the higher role's projection.
var text: String = ""
