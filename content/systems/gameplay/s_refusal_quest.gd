extends System
## Owns quest deadline/outcome selection and pending reward progression after customer/calendar commits.
class_name S_RefusalQuest

#region Scheduling
## Reads real customer outcomes and committed day/phase before resolving the quest.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow, S_DayPhase]}


## Selects the authoritative aggregate and current calendar.
func query() -> QueryBuilder:
	return q.with_all([C_QuestSession, C_DayCycle]).enabled()


## Captures aggregate/calendar/record identity; a later load or offer is a distinct step.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for session: Entity in entities:
		var state: C_QuestSession = session.get_component(C_QuestSession) as C_QuestSession
		var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		var records: Array[RefusalQuestRecord] = state.records.duplicate()
		cmd.add_custom(_advance.bind(session, state, cycle, cycle.day_index, cycle.phase, records))
#endregion

#region Deadline/outcome and reward progression
func _advance(session: Entity, state: C_QuestSession, cycle: C_DayCycle, day_index: int, phase: C_DayCycle.Phase, records: Array[RefusalQuestRecord]) -> void:
	if not EntityAvailability.contains(session, _world) or session.get_component(C_QuestSession) != state \
			or session.get_component(C_DayCycle) != cycle:
		return
	if cycle.day_index != day_index or cycle.phase != phase:
		return

	for record: RefusalQuestRecord in records:
		if record not in state.records:
			continue
		if record.state in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
			var visit: CustomerVisit = CustomerFlowService.find_visit(record.visit_id)
			if cycle.day_index > record.deadline_day:
				RefusalQuestService.resolve(record, RefusalQuestRecord.State.EXPIRED, cycle.day_index)
			elif record.state == RefusalQuestRecord.State.ACTIVE and visit != null and visit.actual == CustomerVisit.Actual.DELIVERED:
				RefusalQuestService.resolve(record, RefusalQuestRecord.State.FAILED, cycle.day_index)
			elif record.state == RefusalQuestRecord.State.ACTIVE and visit != null and visit.actual == CustomerVisit.Actual.PLAYER_DENIED:
				RefusalQuestService.resolve(record, RefusalQuestRecord.State.COMPLETED, cycle.day_index)
			elif cycle.day_index == record.deadline_day and cycle.phase == C_DayCycle.Phase.NIGHT:
				RefusalQuestService.resolve(record, RefusalQuestRecord.State.EXPIRED, cycle.day_index)
		if record.state == RefusalQuestRecord.State.COMPLETED and not record.reward_paid:
			RefusalQuestService.pay_reward(record, cycle.day_index)


#endregion
