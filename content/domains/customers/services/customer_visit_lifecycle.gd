extends RefCounted
## Closes an appearance and owns complaint/followup policy for the existing visit aggregate.
class_name CustomerVisitLifecycle

#region Visit closure and followups
## Закрывает приход однократно и планирует допустимый повтор, сохраняя заказ и личность.
static func finish(visit: CustomerVisit, day: int) -> void:
	if visit.finished:
		return

	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		visit.visit_count > 0 and flow != null and flow.schedule != null
		and cycle != null and cycle.phase == C_DayCycle.Phase.DAY
	):
		var interval: float = flow.schedule.arrival_interval_seconds
		var district: C_District = NpcPopulationQueries.current()
		if district != null and NpcPopulationQueries.person_for(visit.customer_id) != null:
			interval = district.definition.service_transfer_pause
		flow.arrival_cooldown_seconds = maxf(flow.arrival_cooldown_seconds, interval)
	visit.finished = true
	visit.finished_day = day
	CustomerOutcomeService.publish_change(visit, &"appearance_finished")
	if visit.followup_committed and visit.next_followup_day > day:
		return
	if create_complaint(visit, day):
		visit.next_followup_day = 0
		visit.followup_committed = false
		return

	schedule_followup(visit, day)

## Подаёт жалобу с известным именем постоянного жителя; расчёт остаётся у CustomerOutcomeService.
static func create_complaint(
	visit: CustomerVisit,
	day: int,
	reason: CustomerComplaint.Reason = CustomerComplaint.Reason.NOT_DELIVERED,
	force: bool = false,
) -> bool:
	return CustomerOutcomeService.create_complaint(
		visit, day, reason, force, CustomerPresentation.customer_name(visit),
	)

## Планирует допустимый повтор по детерминированному броску для номера повторного визита.
static func schedule_followup(visit: CustomerVisit, day: int) -> bool:
	if (
		visit == null
		or visit.definition == null
		or visit.customer_dead
		or visit.declaration != CustomerVisit.Declaration.NONE
		or (
			visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			and visit.actual != CustomerVisit.Actual.PLAYER_DENIED
		)
		or visit.followup_count >= visit.definition.max_followup_visits
	):
		return false

	var probability: float = clampf(
		visit.definition.followup_probability + visit.followup_probability_delta,
		0.0,
		1.0,
	)
	var random: RandomNumberGenerator = GameTimeQueries.decision(
		String(visit.visit_id), day, "customer/followup", visit.followup_count,
	)
	if random.randf() >= probability:
		return false

	visit.followup_count += 1
	visit.next_followup_day = day + maxi(1, visit.definition.followup_delay_days)
	visit.followup_committed = true
	return true
#endregion
