extends RefCounted
## Inspects pinned Dialogue Manager 4.1 compiled data without evaluating or advancing a line.
class_name ContentDoctorDialogueRules


#region Imported dialogue contract
## Context Script, entry cues and semantic tags are explicit inputs from the owning integration.
static func inspect(
	dialogue: DialogueResource,
	context_script: Script,
	required_cues: PackedStringArray,
	declared_tags: PackedStringArray,
	source: String,
) -> Array[ContentDoctorIssue]:
	var issues: Array[ContentDoctorIssue] = []
	for cue: String in required_cues:
		if not dialogue.cues.has(cue):
			issues.append(
				ContentDoctorIssue.error(
					&"dialogue_cue",
					source,
					"cues/%s" % cue,
					"Required entry cue is missing",
				)
			)
	for cue: Variant in dialogue.cues:
		_check_link(String(dialogue.cues[cue]), dialogue, source, "cues/%s" % cue, issues)
	var methods: Dictionary[String, Dictionary] = _declared_methods(context_script)
	for line_id: Variant in dialogue.lines:
		var line: Dictionary = dialogue.lines[line_id] as Dictionary
		var field: String = "lines/%s" % line_id
		for link_field: String in ["next_id", "next_id_after", "next_sibling_id"]:
			if line.has(link_field):
				_check_link(
					String(line[link_field]),
					dialogue,
					source,
					field + "/" + link_field,
					issues,
				)
		for link_array: String in ["responses", "concurrent_lines"]:
			for target: String in line.get(link_array, PackedStringArray()):
				_check_link(target, dialogue, source, field + "/" + link_array, issues)
		for branch_array: String in ["siblings", "cases"]:
			for branch: Dictionary in line.get(branch_array, []):
				if branch.has("id"):
					_check_link(
						String(branch["id"]),
						dialogue,
						source,
						field + "/" + branch_array,
						issues,
					)
				if branch.has("next_id"):
					_check_link(
						String(branch["next_id"]),
						dialogue,
						source,
						field + "/" + branch_array + "/next_id",
						issues,
					)
				_walk_expression(
					branch.get("condition", { }),
					methods,
					source,
					field + "/" + branch_array + "/condition",
					issues,
				)
		for tag: String in line.get("tags", PackedStringArray()):
			if not declared_tags.has(tag):
				issues.append(
					ContentDoctorIssue.error(
						&"dialogue_tag",
						source,
						field + "/tags",
						"Undeclared semantic tag: %s" % tag,
					)
				)
		for expression_field: String in [
			"condition",
			"mutation",
			"text_replacements",
			"character_replacements",
			"next_id_expression",
		]:
			if not line.has(expression_field):
				continue
			var expression_path: String = field + "/" + expression_field
			if expression_field == "next_id_expression" and not line[expression_field].is_empty():
				issues.append(
					_review(source, expression_path, "Dynamic jump requires author review")
				)
			_walk_expression(line[expression_field], methods, source, expression_path, issues)
	return issues


static func _declared_methods(context_script: Script) -> Dictionary[String, Dictionary]:
	var methods: Dictionary[String, Dictionary] = { }
	var current: Script = context_script
	while current != null:
		for method: Dictionary in current.get_script_method_list():
			var method_name: String = String(method["name"])
			if not method_name.begins_with("_") and not methods.has(method_name):
				methods[method_name] = method
		current = current.get_base_script()
	return methods


static func _check_link(
	target: String,
	dialogue: DialogueResource,
	source: String,
	field: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	if target in [DMConstants.ID_NULL, DMConstants.ID_END, DMConstants.ID_END_CONVERSATION]:
		return
	if not dialogue.lines.has(target):
		issues.append(
			ContentDoctorIssue.error(
				&"dialogue_link",
				source,
				field,
				"Missing imported line target: %s" % target,
			)
		)
#endregion


#region Static expression inspection
static func _walk_expression(
	payload: Variant,
	methods: Dictionary[String, Dictionary],
	source: String,
	field: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	if payload is Array:
		var items: Array = payload as Array
		if not items.is_empty() and items[0] is Dictionary \
				and (items[0] as Dictionary).has("type"):
			_check_tokens(items, methods, source, field, issues)
		else:
			for item: Variant in items:
				_walk_expression(item, methods, source, field, issues)
	elif payload is Dictionary:
		for key: Variant in payload:
			_walk_expression((payload as Dictionary)[key], methods, source, field, issues)


static func _check_tokens(
	tokens: Array,
	methods: Dictionary[String, Dictionary],
	source: String,
	field: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	var index: int = 0
	while index < tokens.size():
		var token: Dictionary = tokens[index] as Dictionary
		var token_type: StringName = StringName(token.get("type", ""))
		if token_type == DMConstants.TOKEN_VARIABLE and token.get("value") == "ctx" \
				and index + 2 < tokens.size():
			var dot: Dictionary = tokens[index + 1] as Dictionary
			var call: Dictionary = tokens[index + 2] as Dictionary
			if dot.get("type") == DMConstants.TOKEN_DOT \
					and call.get("type") == DMConstants.TOKEN_FUNCTION:
				_check_context_call(call, methods, source, field, issues)
				index += 3
				continue
		if token_type not in [
			DMConstants.TOKEN_STRING,
			DMConstants.TOKEN_NUMBER,
			DMConstants.TOKEN_BOOL,
			DMConstants.TOKEN_NOT,
			DMConstants.TOKEN_AND_OR,
			DMConstants.TOKEN_COMPARISON,
			DMConstants.TOKEN_OPERATOR,
			DMConstants.TOKEN_NULL_COALESCE,
			DMConstants.TOKEN_GROUP,
			DMConstants.TOKEN_ARRAY,
			DMConstants.TOKEN_COMMENT,
			DMConstants.TOKEN_PARENS_CLOSE,
			DMConstants.TOKEN_BRACKET_CLOSE,
			DMConstants.TOKEN_BRACE_CLOSE,
		]:
			issues.append(
				_review(
					source,
					field,
					"Unsupported dynamic expression requires author review; it was not executed",
				)
			)
		_walk_expression(token.get("value"), methods, source, field, issues)
		index += 1


static func _check_context_call(
	call: Dictionary,
	methods: Dictionary[String, Dictionary],
	source: String,
	field: String,
	issues: Array[ContentDoctorIssue],
) -> void:
	var method_name: String = String(call.get("function", ""))
	var arguments: Array = call.get("value", []) as Array
	var argument_count: int = arguments.size()
	# The pinned compiler keeps a lone closing-paren group for a zero-argument call.
	if argument_count > 0:
		var final_argument: Array = arguments[argument_count - 1] as Array
		if final_argument.size() == 1 \
				and (final_argument[0] as Dictionary).get("type") == DMConstants.TOKEN_PARENS_CLOSE:
			argument_count -= 1
	if not methods.has(method_name):
		issues.append(
			ContentDoctorIssue.error(
				&"dialogue_context_method",
				source,
				field,
				"ctx.%s is not a declared public context method" % method_name,
			)
		)
	else:
		var method: Dictionary = methods[method_name]
		var maximum: int = (method.get("args", []) as Array).size()
		var minimum: int = maximum - (method.get("default_args", []) as Array).size()
		if argument_count < minimum or argument_count > maximum:
			issues.append(
				ContentDoctorIssue.error(
					&"dialogue_context_arguments",
					source,
					field,
					"ctx.%s requires %d..%d arguments" % [method_name, minimum, maximum],
				)
			)
	_walk_expression(arguments, methods, source, field, issues)


static func _review(source: String, field: String, message: String) -> ContentDoctorIssue:
	var issue: ContentDoctorIssue = ContentDoctorIssue.error(
		&"dialogue_dynamic_expression",
		source,
		field,
		message,
	)
	issue.severity = ContentDoctorIssue.Severity.REVIEW_REQUIRED
	return issue
#endregion
