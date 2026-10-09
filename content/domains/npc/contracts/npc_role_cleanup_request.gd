extends RefCounted
## Synchronous native lifecycle boundary; higher roles clean their state even during passive restore.
class_name NpcRoleCleanupRequest

enum Kind { RESET_PREPARE, RESET_RELEASE, SUSPEND, DEATH }

## Native lifecycle step, preserving the ordering of role and engine cleanup.
var kind: Kind = Kind.RESET_PREPARE
## Authoritative death day; meaningful only for DEATH.
var day_index: int = 0

#region Request construction
## Captures the explicit native lifecycle step without retaining an Entity.
func _init(cleanup_kind: Kind, death_day: int = 0) -> void:
	kind = cleanup_kind
	day_index = death_day
#endregion
