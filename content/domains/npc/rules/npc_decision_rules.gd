extends RefCounted
## Validates the captured due step against authoritative calendar and population state.
class_name NpcDecisionRules

#region Due-step predicate
## Rejects a superseded calendar or inactive/terminal actor without advancing any clock.
static func matches_step(person: NpcRecord, decision: C_NpcDecision, cycle: C_DayCycle) -> bool:
	return person != null and person.death_day == 0 \
		and person.placement == NpcRecord.Placement.STREET \
		and decision.scheduled_delta > 0.0 \
		and cycle.phase != C_DayCycle.Phase.NIGHT \
		and decision.scheduled_day == cycle.day_index \
		and decision.scheduled_phase == int(cycle.phase)
#endregion
