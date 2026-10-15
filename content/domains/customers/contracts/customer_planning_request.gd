extends RefCounted
## Explicit planning command; the owning Observer fills its completion receipt.
class_name CustomerPlanningRequest

## Sole command handler is O_CustomerPlanning.
const EVENT: StringName = &"customer_planning_requested"
## Terminal successful session preparation; outcomes may reconcile after planning commits.
const RECONCILED: StringName = &"customer_session_reconciled"

enum Kind {
	PLAN_DAY,
	RECONCILE_MORNING,
	REACTIVATE_FOLLOWUPS,
	RECONCILE_SESSION,
}

## Discrete operation, never a recurring clock.
var kind: Kind = Kind.PLAN_DAY
## ECS-owned aggregate; isolated contract tests may supply an unattached Component.
var flow: C_CustomerFlow
## Explicit target day for planning/reactivation.
var day_index: int = 0
## Authored delivery payment for newly created visits.
var payment: int = 0
## Captured phase for RECONCILE_SESSION; not a calendar publication.
var phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING
## Transient reconstruction generation captured with the authoritative Components.
var generation: int = 0
## Required by RECONCILE_MORNING and RECONCILE_SESSION.
var cycle: C_DayCycle
## Optional wallet; unpaid penalties remain retryable through outcome settlement.
var wallet: C_Wallet
## Terminal receipt for success or rejection; false while handler work remains pending.
var completed: bool = false
## Changed visit count for reconciliation/reactivation.
var affected_visits: int = 0
## Empty on successful completion; nonempty with completed=true records a terminal rejection.
var rejection_reason: StringName = &""
