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
		"participation": "ACTIVE" if _body_participating(person, actor) else "DORMANT",
		"participation_reason": String(decision.participation_reason),
		"pending_arrival": _pending_arrival(person),
		"participation_pin": "service_role" if actor.has_active_role() else "",
		"wake_pending": decision.wake_requested,
	}


static func _body_participating(person: NpcRecord, actor: E_DistrictNpc) -> bool:
	return (
		person.placement == NpcRecord.Placement.STREET and person.death_day == 0 \
				and actor.enabled
		and not actor.has_component(C_Death)
	)


static func _pending_arrival(person: NpcRecord) -> bool:
	var location: DEF_NpcSchedule.Location = person.profile.schedule.location_for(
		person.planned_day,
		person.planned_phase as C_DayCycle.Phase,
	)
	return (
		person.death_day == 0 and person.placement != NpcRecord.Placement.STREET \
				and not person.phase_complete
		and location == DEF_NpcSchedule.Location.STREET
	)


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
