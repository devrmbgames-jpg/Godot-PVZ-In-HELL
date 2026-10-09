extends RefCounted
## Synchronous higher-role presence query; the result is transient, never a second role state.
class_name NpcRolePresenceRequest

## Written only by the installed role owner during native signal dispatch.
var active: bool = false
