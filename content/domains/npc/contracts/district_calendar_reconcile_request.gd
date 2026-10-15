extends RefCounted
## Explicit district bootstrap/recovery command; never a committed calendar transition.
class_name DistrictCalendarReconcileRequest

## O_DistrictLifecycle is the sole handler.
const EVENT: StringName = &"district_calendar_reconcile_requested"
## Captured aggregate identity across the queued boundary.
var district: C_District
## Captured authoritative calendar identity.
var cycle: C_DayCycle
## Requested current day, without advancing time.
var day_index: int = 0
## Requested current phase, without advancing time.
var phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
## Terminal receipt, set only after the handler runs or reconstruction cancels it.
var completed: bool = false
## Empty for success; stale/removed owners reject without mutation.
var rejection_reason: StringName = &""
