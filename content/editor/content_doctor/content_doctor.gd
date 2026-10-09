extends RefCounted
## One detached content scan; existing authoring providers retain their contract authority.
class_name ContentDoctor

var _issues: Array[ContentDoctorIssue] = []
var _resources: Dictionary[int, bool] = { }
var _dependencies: Dictionary[String, bool] = { }
var _districts: Array[DEF_District] = []
var _customer_dialogues: Dictionary[String, PackedStringArray] = { }
var _referenced_paths: Dictionary[String, bool] = { }
var _file_contracts: Array[Dictionary] = []
var _checked_file_fields: Dictionary[String, bool] = { }
var _scene_count: int = 0
var _dialogue_count: int = 0


#region Full authored scan
## Enumerates project-owned authored content only; nodes never enter the gameplay tree.
func scan(root_path: String = "res://content") -> Dictionary[String, Variant]:
	_reset()
	var paths: PackedStringArray = PackedStringArray()
	_collect_paths(root_path, paths)
	return _scan_paths(paths)


## Focused checks use the same native dependency graph and providers as a full scan.
func scan_paths(paths: PackedStringArray) -> Dictionary[String, Variant]:
	_reset()
	return _scan_paths(paths)


func _reset() -> void:
	_issues.clear()
	_resources.clear()
	_dependencies.clear()
	_districts.clear()
	_customer_dialogues.clear()
	_referenced_paths.clear()
	_file_contracts.clear()
	_checked_file_fields.clear()
	_scene_count = 0
	_dialogue_count = 0


func _scan_paths(paths: PackedStringArray) -> Dictionary[String, Variant]:
	paths.sort()
	var accepted: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if _check_dependencies(path, []):
			accepted.append(path)
	# Factory inputs come from the same typed district definitions used at runtime.
	for path: String in accepted:
		if path.get_extension() in ["tres", "res"]:
			_visit_resource(load(path), path)
	_include_references(accepted)
	var dialogues: PackedStringArray = PackedStringArray()
	var index: int = 0
	while index < accepted.size():
		var path: String = accepted[index]
		match path.get_extension():
			"tres", "res":
				_visit_resource(load(path), path)
			"tscn", "scn":
				_inspect_scene(path)
			"dialogue":
				dialogues.append(path)
		_include_references(accepted)
		index += 1
	for path: String in dialogues:
		_inspect_dialogue(path)
	var data: Array[Dictionary] = []
	var errors: int = 0
	var reviews: int = 0
	for issue: ContentDoctorIssue in _issues:
		data.append(issue.data())
		if issue.severity == ContentDoctorIssue.Severity.ERROR:
			errors += 1
		else:
			reviews += 1
	return {
		"valid": errors == 0 and reviews == 0,
		"errors": errors,
		"review_required": reviews,
		"resources": _resources.size(),
		"scenes": _scene_count,
		"dialogues": _dialogue_count,
		"issues": data,
	}


func _collect_paths(directory_path: String, paths: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		_issues.append(
			ContentDoctorIssue.error(
				&"content_directory",
				directory_path,
				".",
				"Content directory cannot be opened",
			)
		)
		return
	for file: String in directory.get_files():
		if file.get_extension() in ["tres", "res", "tscn", "scn", "dialogue"]:
			paths.append(directory_path.path_join(file))
	for child: String in directory.get_directories():
		if not child.begins_with("."):
			_collect_paths(directory_path.path_join(child), paths)


func _check_dependencies(path: String, ancestry: Array[String]) -> bool:
	if ancestry.has(path):
		for message: String in EntityAuthoringPreviewRules.dependency_issues(path):
			_issues.append(
				ContentDoctorIssue.error(&"resource_cycle", path, "dependencies", message)
			)
		return false
	if _dependencies.has(path):
		return _dependencies[path]
	if not ResourceLoader.exists(path):
		_issues.append(
			ContentDoctorIssue.error(
				&"resource_path",
				path,
				"dependencies",
				"Referenced resource does not exist",
			)
		)
		_dependencies[path] = false
		return false
	var branch: Array[String] = ancestry.duplicate()
	branch.append(path)
	var valid: bool = true
	for dependency: String in ResourceLoader.get_dependencies(path):
		var target: String = dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if target.begins_with("uid://"):
			var resource_id: int = ResourceUID.text_to_id(target)
			if ResourceUID.has_id(resource_id):
				target = ResourceUID.get_id_path(resource_id)
		if target.get_extension() in ["tres", "res", "tscn", "scn", "dialogue"]:
			if not _check_dependencies(target, branch):
				valid = false
		elif not ResourceLoader.exists(target):
			_issues.append(
				ContentDoctorIssue.error(
					&"resource_path",
					path,
					"dependencies",
					"Missing dependency: %s" % target,
				)
			)
			valid = false
	_dependencies[path] = valid
	return valid


func _include_references(accepted: PackedStringArray) -> void:
	for path: String in _referenced_paths:
		if not accepted.has(path) and _check_dependencies(path, []):
			accepted.append(path)
	for contract: Dictionary in _file_contracts:
		var field_key: String = "%s/%s" % [contract["source"], contract["field"]]
		if _checked_file_fields.has(field_key):
			continue
		_checked_file_fields[field_key] = true
		var path: String = String(contract["path"])
		if not _check_dependencies(path, []):
			continue
		# Type checks load only after cycle/missing-dependency preflight; they never instantiate.
		var resource: Resource = load(path)
		var expected_type: String = String(contract["type"])
		var correct_type: bool = (
			resource is PackedScene
			if expected_type == "PackedScene"
			else resource is DialogueResource
		)
		if not correct_type:
			_issues.append(
				ContentDoctorIssue.error(
					&"resource_type",
					String(contract["source"]),
					String(contract["field"]),
					"Expected %s: %s" % [expected_type, path],
				)
			)
#endregion


#region Resources and explicit factory inputs
func _visit_resource(resource: Resource, source: String) -> void:
	if resource == null:
		_issues.append(
			ContentDoctorIssue.error(
				&"resource_load",
				source,
				".",
				"Authored resource cannot be loaded",
			)
		)
		return
	if resource is PackedScene:
		if not resource.resource_path.is_empty():
			_referenced_paths[resource.resource_path] = true
		return
	if resource is Script or _resources.has(resource.get_instance_id()):
		return
	_resources[resource.get_instance_id()] = true
	if not resource.resource_path.is_empty():
		source = resource.resource_path
	_issues.append_array(ContentDoctorResourceRules.inspect(resource, source))
	if resource is DEF_District:
		_districts.append(resource as DEF_District)
	if resource is DEF_Customer:
		_capture_customer_dialogue(resource as DEF_Customer)
	for property: Dictionary in resource.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var field: String = String(property["name"])
		var value: Variant = resource.get(field)
		_capture_file_reference(property, value, source)
		_visit_value(value, "%s/%s" % [source, field])


func _capture_file_reference(property: Dictionary, value: Variant, source: String) -> void:
	if int(property["hint"]) != PROPERTY_HINT_FILE or not value is String:
		return
	var path: String = String(value)
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		_issues.append(
			ContentDoctorIssue.error(
				&"resource_path",
				source,
				String(property["name"]),
				"Missing referenced resource: %s" % path,
			)
		)
		return
	if path.get_extension() not in ["tscn", "scn", "tres", "res", "dialogue"]:
		return
	_referenced_paths[path] = true
	var hint: String = String(property["hint_string"])
	var expected_type: String = ""
	if hint.contains("*.tscn"):
		expected_type = "PackedScene"
	elif hint.contains("*.dialogue"):
		expected_type = "DialogueResource"
	if not expected_type.is_empty():
		_file_contracts.append(
			{
				"source": source,
				"field": String(property["name"]),
				"path": path,
				"type": expected_type,
			}
		)


func _visit_value(value: Variant, source: String) -> void:
	if value is Resource:
		_visit_resource(value as Resource, source)
	elif value is Array:
		for index: int in (value as Array).size():
			_visit_value((value as Array)[index], "%s/%d" % [source, index])
	elif value is Dictionary:
		for key: Variant in value:
			_visit_value((value as Dictionary)[key], "%s/%s" % [source, key])


func _capture_customer_dialogue(customer: DEF_Customer) -> void:
	var path: String = customer.dialogue_resource_path
	if path.is_empty():
		path = CustomerDialogueService.DIALOGUE_PATH
	var cues: PackedStringArray = _customer_dialogues.get(
		path,
		PackedStringArray(["challenge", "direct", "followup", "voluntary_refusal", "false_taken"]),
	)
	if customer.dialogue_mode == DEF_Customer.DialogueMode.RIDDLE and not cues.has("riddle"):
		cues.append("riddle")
	_customer_dialogues[path] = cues


func _inspect_scene(path: String) -> void:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		_issues.append(
			ContentDoctorIssue.error(
				&"scene_load",
				path,
				".",
				"Authored scene must be a PackedScene",
			)
		)
		return
	var detached: Node = scene.instantiate()
	_scene_count += 1
	var candidates: Array[Node] = [detached]
	candidates.append_array(detached.find_children("*", "", true, false))
	for candidate: Node in candidates:
		for property: Dictionary in candidate.get_property_list():
			if int(property["usage"]) & PROPERTY_USAGE_STORAGE != 0:
				var field: String = String(property["name"])
				_capture_file_reference(
					property,
					candidate.get(field),
					"%s:%s" % [path, detached.get_path_to(candidate)],
				)
				_visit_value(
					candidate.get(field),
					"%s:%s/%s" % [path, detached.get_path_to(candidate), field],
				)
		for metadata: StringName in candidate.get_meta_list():
			_visit_value(
				candidate.get_meta(metadata),
				"%s:%s/metadata/%s" % [path, detached.get_path_to(candidate), metadata],
			)
	if detached is E_DistrictNpc:
		_inspect_npc_prefab(detached as E_DistrictNpc, path)
	elif path == DistrictPopulationService.ADDRESS_PREFAB:
		var uses: int = 0
		for district: DEF_District in _districts:
			for place: DEF_DistrictPlace in district.places:
				if place != null and place.kind == DEF_DistrictPlace.Kind.HOME:
					uses += 1
					_issues.append_array(
						ContentDoctorSceneRules.inspect(
							detached,
							"%s [address:%s]" % [path, place.key],
							null,
							null,
							place,
						)
					)
		if uses == 0:
			_missing_factory_context(path)
			_issues.append_array(ContentDoctorSceneRules.inspect(detached, path))
	else:
		_issues.append_array(ContentDoctorSceneRules.inspect(detached, path))
	detached.free()


func _inspect_npc_prefab(actor: E_DistrictNpc, source: String) -> void:
	var uses: int = 0
	for district: DEF_District in _districts:
		if not ContentDoctorResourceRules.inspect(district, district.resource_path).is_empty():
			continue
		for person: NpcRecord in NpcPopulationRules.initial_records(district, 1):
			if person.profile.npc_scene_path != source:
				continue
			uses += 1
			_issues.append_array(
				ContentDoctorSceneRules.inspect(
					actor,
					"%s [profile:%s]" % [source, person.profile.resource_path],
					person,
					district,
				)
			)
	if uses == 0:
		# An unused prefab still gets structural diagnostics; mandatory inputs cannot be guessed.
		_missing_factory_context(source)
		_issues.append_array(ContentDoctorSceneRules.inspect(actor, source))


func _missing_factory_context(source: String) -> void:
	var issue: ContentDoctorIssue = ContentDoctorIssue.error(
		&"factory_context",
		source,
		".",
		"Prefab has no declared district producer inputs in this scan",
	)
	issue.severity = ContentDoctorIssue.Severity.REVIEW_REQUIRED
	_issues.append(issue)
#endregion


#region Declared dialogue integrations
func _inspect_dialogue(path: String) -> void:
	var dialogue: DialogueResource = load(path) as DialogueResource
	if dialogue == null:
		_issues.append(
			ContentDoctorIssue.error(
				&"dialogue_resource",
				path,
				".",
				"Dialogue import must produce DialogueResource",
			)
		)
		return
	_dialogue_count += 1
	var context_script: Script = CustomerDialogueContext
	var cues: PackedStringArray = _customer_dialogues.get(path, PackedStringArray())
	if path == NpcDialogueService.DIALOGUE_PATH:
		context_script = NpcStreetDialogueContext
		cues = ["street", "provocation", "delivery_request", "broken_promise"]
	elif path == CustomerDialogueService.DIALOGUE_PATH:
		cues = [
			"challenge",
			"direct",
			"followup",
			"riddle",
			"voluntary_refusal",
			"false_taken",
			"provocation",
			"home_request",
			"broken_promise",
		]
	elif not _customer_dialogues.has(path):
		var issue: ContentDoctorIssue = ContentDoctorIssue.error(
			&"dialogue_context",
			path,
			".",
			"Dialogue has no declared gameplay context integration",
		)
		issue.severity = ContentDoctorIssue.Severity.REVIEW_REQUIRED
		_issues.append(issue)
		return
	_issues.append_array(
		ContentDoctorDialogueRules.inspect(
			dialogue,
			context_script,
			cues,
			PackedStringArray(["hon", "lie", "prs", "thr", "flr", "jok", "sub"]),
			path,
		)
	)
#endregion
