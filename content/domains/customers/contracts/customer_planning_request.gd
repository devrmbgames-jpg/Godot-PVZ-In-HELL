extends RefCounted
## Explicit planning command; the owning Observer fills its completion receipt.
class_name CustomerPlanningRequest

## Sole command handler is O_CustomerPlanning.
const EVENT: StringName = &"customer_planning_requested"

enum Kind { PLAN_DAY, RECONCILE_MORNING, REACTIVATE_FOLLOWUPS }

## Discrete operation, never a recurring clock.
var kind: Kind = Kind.PLAN_DAY
## ECS-owned aggregate; isolated contract tests may supply an unattached Component.
var flow: C_CustomerFlow
## Explicit target day for planning/reactivation.
var day_index: int = 0
## Authored delivery payment for newly created visits.
var payment: int = 0
## Required only by RECONCILE_MORNING.
var cycle: C_DayCycle
## Optional wallet; unpaid penalties remain retryable through outcome settlement.
var wallet: C_Wallet
## Terminal receipt, false while the handler's CommandBuffer remains pending.
var completed: bool = false
## Changed visit count for reconciliation/reactivation.
var affected_visits: int = 0
## Empty on completion; a queued runtime command may reject a stale session/day.
var rejection_reason: StringName = &""
