extends RefCounted
## Command receipt: PENDING is acceptance, terminal state is written only by O_PackageOpening.
class_name PackageOpenResult

const EVENT: StringName = &"package_open_resolved"
enum Status { PENDING, COMMITTED, REJECTED }

## Current command status, never inferred from the fact that it was queued.
var status: Status = Status.REJECTED
## Machine-readable rejection or completion reason.
var reason: StringName = &"access_denied"
## Transient request correlation, independent of persistent package identity.
var correlation_id: StringName = &""
## Stable shipment identity, retained after the physical package is removed.
var package_id: String = ""
## Actor identity captured at submission; no live reference is needed for diagnostics.
var actor_id: String = ""
