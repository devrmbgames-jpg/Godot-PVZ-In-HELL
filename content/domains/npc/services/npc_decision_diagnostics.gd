extends RefCounted
## Detached read provider over existing AI state; no planner, timers or mutable mirror.
class_name NpcDecisionDiagnostics


#region Read provider
## Captures the current authored obligation and local execution reasons without advancing AI.
static func actor_state(actor: E_DistrictNpc) -> Dictionary[String, Variant]:
	var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
	var person: NpcRecord = NpcPopulationQueries.person_for(identity.npc_id)
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	return {
		"npc_id": String(identity.npc_id),
		"obligation": String(person.goal_id),
		"source": decision.obligation_source,
		"selection_reason": String(decision.selection_reason),
		"owner": C_NpcDecision.Owner.keys()[decision.intent_owner],
		"behavior": decision.active_behavior,
		"action_generation": decision.action_generation,
		"action_goal": String(decision.action_goal_id),
		"action_status": C_NpcDecision.ActionStatus.keys()[decision.action_status],
		"action_reason": String(decision.action_reason),
		"local_activity": String(decision.local_activity_id),
		"wake_pending": decision.wake_requested,
	}


## Captures bounded work accounting from the current cadence owner.
static func budget_state(district: C_District) -> Dictionary[String, Variant]:
	return {
		"due": district.decisions_due,
		"processed": district.decisions_processed,
		"deferred": district.decisions_deferred,
		"cap": district.definition.decision_work_units,
		"cursor": String(district.decision_cursor),
		"max_wait_ticks": district.decision_max_wait_ticks,
	}
#endregion
