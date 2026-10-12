extends RefCounted
## Pure named inspection choices; the visit journal owns committed outcomes, never this helper.
class_name CustomerInspectionRules


#region Deterministic inspection choices
## Returns the same 0–1 sample for a choice and visit incarnation without advancing a stream.
static func roll(visit: CustomerVisit, choice: String) -> float:
	var random: RandomNumberGenerator = GameTimeQueries.decision(
		String(visit.visit_id),
		maxi(1, visit.last_visit_day),
		"customer/inspection/" + choice,
		visit.visit_count,
	)
	return random.randf()
#endregion
