extends RefCounted
## Read-only quest authoring provider: stable IDs, persisted Definition reference and real package target.
class_name RefusalQuestValidator

#region Definition and issuer diagnostics
## Returns actionable resource/field diagnostics; no content expressions are evaluated.
static func definition_issues(definition: DEF_RefusalQuest, context: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if definition == null:
		issues.append(_issue(context, "definition", "Missing DEF_RefusalQuest"))
		return issues

	var source: String = definition.resource_path if context.is_empty() else context
	if definition.key == &"":
		issues.append(_issue(source, "key", "Quest content ID must be nonempty"))
	if not definition.resource_path.begins_with("res://content/definitions/") or not ResourceLoader.exists(definition.resource_path):
		issues.append(_issue(source, "resource_path", "Quest Definition must use a durable authored path in content/definitions"))
	if definition.reward < 0:
		issues.append(_issue(source, "reward", "Reward must be nonnegative"))
	if definition.minimum_deadline_days < 1:
		issues.append(_issue(source, "minimum_deadline_days", "Deadline must cover at least one day"))
	for field: StringName in [&"offer_text", &"accepted_text", &"accept_text", &"ignore_text"]:
		var value: String = String(definition.get(field))
		if value.strip_edges().is_empty():
			issues.append(_issue(source, String(field), "Quest presentation text must be nonempty"))
	return issues


## An absent optional quest disables the issuer; configured quests must satisfy their contract.
static func issuer_issues(shop: C_Trader, context: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if shop.trader_key == &"":
		issues.append(_issue(context, "trader_key", "Quest issuer ID must be nonempty"))
	if shop.profile != null and shop.profile.refusal_quest != null:
		issues.append_array(definition_issues(shop.profile.refusal_quest, context))
	return issues
#endregion

#region Persistent target diagnostics
## Validates the selected authored visit, actual package identity and registration before setup.
static func target_issues(visit: CustomerVisit, registration: PackageRegistrationRecord, package: C_Package, context: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if visit.visit_id == &"" or visit.customer_id == &"":
		issues.append(_issue(context, "visit_id/customer_id", "Quest target requires stable visit and recipient IDs"))
	if package == null or package.package_id.is_empty() or visit.package_id.is_empty() \
			or package.package_id != visit.package_id or registration.package_id != visit.package_id:
		issues.append(_issue(context, "package_id", "Quest must target the same actual registered package as its visit"))
	if not registration.active or registration.number <= 0:
		issues.append(_issue(context, "registration", "Quest target requires an active positive display number"))
	return issues


## Validates the persisted aggregate before any live snapshot mutation; terminal targets may be gone.
static func session_issues(state: C_QuestSession, context: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var seen: Dictionary[StringName, bool] = {}
	for record: RefusalQuestRecord in state.records:
		var source: String = context + "/" + String(record.quest_id)
		issues.append_array(definition_issues(record.definition, source))
		if record.package_id.is_empty() or record.visit_id == &"" or record.issuer_key == &"" \
				or record.quest_id != StringName("refusal/" + record.package_id) or seen.has(record.quest_id):
			issues.append(_issue(source, "quest_id/package_id/visit_id/issuer_key", "Quest requires unique stable operation and target IDs"))
		seen[record.quest_id] = true
		if record.display_number <= 0 or record.offered_day < 1 or record.deadline_day < record.offered_day + 1 or record.reward < 0:
			issues.append(_issue(source, "reward/deadline/display_number", "Invalid accepted quest snapshots"))
		if record.state not in RefusalQuestRecord.State.values():
			issues.append(_issue(source, "state", "Unknown quest outcome"))
		elif record.state in [RefusalQuestRecord.State.OFFERED, RefusalQuestRecord.State.ACTIVE]:
			if record.resolved_day != 0 or record.reward_paid:
				issues.append(_issue(source, "resolved_day/reward_paid", "Unresolved quest cannot contain a terminal receipt"))
		elif record.resolved_day < record.offered_day or (record.reward_paid and record.state != RefusalQuestRecord.State.COMPLETED):
			issues.append(_issue(source, "resolved_day/reward_paid", "Reward receipt requires a completed quest"))
	return issues


static func _issue(source: String, field: String, message: String) -> Dictionary:
	return {"resource": source, "field": field, "code": &"invalid_refusal_quest", "message": message}
#endregion
