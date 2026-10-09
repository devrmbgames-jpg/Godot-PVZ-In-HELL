extends RefCounted
## Pure authored data checks; scene capabilities are checked by the existing Entity compiler.
class_name ContentDoctorResourceRules


#region Typed definition contracts
## Checks the current resource once; the scan owns traversal of nested resources/containers.
static func inspect(resource: Resource, source: String) -> Array[ContentDoctorIssue]:
	var issues: Array[ContentDoctorIssue] = []
	if resource is GameDefinition or resource is EntityTrait:
		_check_numeric_fields(resource, source, issues)
		_check_file_fields(resource, source, issues)
	if resource is DEF_NpcAttack:
		_check_attack(resource as DEF_NpcAttack, source, issues)
	if resource is DEF_District:
		_check_district(resource as DEF_District, source, issues)
	if resource is DEF_EntityTemplate:
		for issue: EntityBuildPlan.Issue in EntityBuildRules.template_issues(
			resource as DEF_EntityTemplate,
			source,
		):
			issues.append(
				ContentDoctorIssue.error(
					issue.code,
					source,
					"traits/%s" % issue.source,
					issue.message,
				)
			)
	if resource is DEF_NpcSchedule:
		_check_schedule(resource as DEF_NpcSchedule, source, issues)
	if resource is DEF_NpcProfile and not (resource as DEF_NpcProfile).valid_rules():
		issues.append(
			ContentDoctorIssue.error(
				&"npc_traits",
				source,
				"rules",
				"NPC traits conflict, repeat or have no schedule",
			)
		)
	if resource is DEF_InteractionAction and resource.get_script() == DEF_InteractionAction:
		issues.append(
			ContentDoctorIssue.error(
				&"action_executor",
				source,
				"script",
				"Action requires a concrete executor",
			)
		)
	if resource is DEF_RefusalQuest:
		for issue: Dictionary in RefusalQuestValidator.definition_issues(
			resource as DEF_RefusalQuest,
			source,
		):
			issues.append(
				ContentDoctorIssue.error(
					&"quest_definition",
					source,
					String(issue["field"]),
					String(issue["message"]),
				)
			)
	if resource is C_Trader:
		for issue: Dictionary in RefusalQuestValidator.issuer_issues(resource as C_Trader, source):
			issues.append(
				ContentDoctorIssue.error(
					&"quest_issuer",
					source,
					String(issue["field"]),
					String(issue["message"]),
				)
			)
	return issues


static func _check_attack(
	attack: DEF_NpcAttack,
	source: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	for field: StringName in [
		&"damage",
		&"minimum_range",
		&"maximum_range",
		&"windup_seconds",
		&"active_seconds",
		&"recovery_seconds",
		&"cooldown_seconds",
		&"projectile_speed",
		&"projectile_lifetime",
	]:
		if float(attack.get(field)) < 0.0:
			issues.append(
				ContentDoctorIssue.error(
					&"attack_range",
					source,
					String(field),
					"Attack distance/time/damage cannot be negative",
				)
			)
	if attack.minimum_range > attack.maximum_range:
		issues.append(
			ContentDoctorIssue.error(
				&"attack_range",
				source,
				"minimum_range",
				"Minimum distance exceeds maximum distance",
			)
		)


static func _check_district(
	district: DEF_District,
	source: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	var places: Dictionary[StringName, DEF_DistrictPlace] = { }
	for index: int in district.places.size():
		var place: DEF_DistrictPlace = district.places[index]
		var field: String = "places/%d" % index
		if place == null or place.key.is_empty():
			issues.append(
				ContentDoctorIssue.error(
					&"district_place",
					source,
					field,
					"District place requires a stable authored key",
				)
			)
			continue
		if places.has(place.key):
			issues.append(
				ContentDoctorIssue.error(
					&"district_place",
					source,
					field,
					"Duplicate place key: %s" % place.key,
				)
			)
		places[place.key] = place
		if not place.position.is_finite() or not place.activity_offset.is_finite():
			issues.append(
				ContentDoctorIssue.error(
					&"district_place",
					source,
					field,
					"Place positions must be finite",
				)
			)
	for place: DEF_DistrictPlace in places.values():
		for neighbour: String in place.neighbours:
			if not places.has(StringName(neighbour)):
				issues.append(
					ContentDoctorIssue.error(
						&"district_place",
						source,
						"places/%s/neighbours" % place.key,
						"Unknown neighbour: %s" % neighbour,
					)
				)
	var routes: PackedStringArray = district.shade_route.duplicate()
	if not district.shade_refuge.is_empty():
		routes.append(String(district.shade_refuge))
	for route: String in routes:
		if not places.has(StringName(route)):
			issues.append(
				ContentDoctorIssue.error(
					&"district_place",
					source,
					"shade_route/shade_refuge",
					"Unknown place: %s" % route,
				)
			)
	for index: int in district.profiles.size():
		if district.profiles[index] == null:
			issues.append(
				ContentDoctorIssue.error(
					&"district_profile",
					source,
					"profiles/%d" % index,
					"District profile cannot be empty",
				)
			)


static func _check_schedule(
	schedule: DEF_NpcSchedule,
	source: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	for phase_field: StringName in [&"morning", &"day", &"evening"]:
		if not DEF_NpcSchedule.Location.values().has(int(schedule.get(phase_field))):
			issues.append(
				ContentDoctorIssue.error(
					&"schedule_location",
					source,
					String(phase_field),
					"Unknown schedule location",
				)
			)
	for weekday: int in schedule.weekdays:
		if weekday < 0 or weekday > 6:
			issues.append(
				ContentDoctorIssue.error(
					&"schedule_weekday",
					source,
					"weekdays",
					"Weekday must be between 0 and 6",
				)
			)
#endregion


#region Native authored numeric metadata
static func _check_file_fields(
	resource: Resource,
	source: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	for property: Dictionary in resource.get_property_list():
		if int(property["hint"]) != PROPERTY_HINT_FILE:
			continue
		var field: String = String(property["name"])
		var path: String = String(resource.get(field))
		if path.is_empty():
			continue
		var expected_type: String = ""
		if String(property["hint_string"]).contains("*.tscn"):
			expected_type = "PackedScene"
		elif String(property["hint_string"]).contains("*.dialogue"):
			expected_type = "DialogueResource"
		if not ResourceLoader.exists(path, expected_type):
			issues.append(
				ContentDoctorIssue.error(
					&"resource_path",
					source,
					field,
					"Missing referenced resource: %s" % path,
				)
			)


static func _check_numeric_fields(
	resource: Resource,
	source: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	for property: Dictionary in resource.get_property_list():
		var usage: int = int(property["usage"])
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var field: String = String(property["name"])
		var value: Variant = resource.get(field)
		if value is float and not is_finite(float(value)):
			issues.append(
				ContentDoctorIssue.error(
					&"nonfinite_definition",
					source,
					field,
					"Authored number must be finite",
				)
			)
			continue
		if int(property["hint"]) != PROPERTY_HINT_RANGE or not (value is float or value is int):
			continue
		var hint: PackedStringArray = String(property["hint_string"]).split(",")
		if hint.size() < 2:
			continue
		var below: bool = float(value) < float(hint[0]) and not hint.has("or_less")
		var above: bool = float(value) > float(hint[1]) and not hint.has("or_greater")
		if below or above:
			issues.append(
				ContentDoctorIssue.error(
					&"definition_range",
					source,
					field,
					"Value %s exceeds authored range %s..%s" % [value, hint[0], hint[1]],
				)
			)
#endregion
