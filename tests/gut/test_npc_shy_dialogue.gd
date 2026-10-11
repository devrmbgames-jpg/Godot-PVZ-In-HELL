extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Both personal shy resources read real warning state and preserve existing role transactions.

const SHY_PATH: String = "res://content/domains/npc/definitions/def_npc_archetype_shy.tres"


#region Personal shy fixture
func _shy_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = load(SHY_PATH) as DEF_NpcArchetype
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person
#endregion


#region Authored imports and persistent identity
func test_shy_native_imports_preserve_role_cues_and_committed_selection() -> void:
	var person: NpcRecord = _shy_person()
	var body: E_DistrictNpc = _stage(person)
	assert_eq(person.profile.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	for path: String in person.profile.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
	var saved: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(person)) as NpcRecord
	assert_eq(saved.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(saved.display_name, person.display_name)
	for repeat: int in range(3):
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
#endregion


#region Real warning views and role registration guards
func test_both_shy_street_tones_escalate_from_the_trait_warning_without_mutating_it() -> void:
	var person: NpcRecord = _shy_person()
	var body: E_DistrictNpc = _stage(person)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var quiet_lines: Array[String] = []
	var warned_lines: Array[String] = []
	for path: String in person.profile.dialogue_variants:
		awareness.warned_rules.clear()
		var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
		assert_true(context.begin())
		assert_false(context.gaze_warning_given())
		var resource: DialogueResource = _resource(path)
		var quiet: DialogueLine = await _line(resource, context, "street")
		quiet_lines.append(quiet.text)
		awareness.warned_rules.append(DEF_NpcTrait.Kind.GAZE_AVERSION)
		awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION] = 2.0
		var snapshot: Dictionary = SaveDataCodec.encode(person) as Dictionary
		assert_true(context.gaze_warning_given())
		var warned: DialogueLine = await _line(resource, context, "street")
		warned_lines.append(warned.text)
		assert_ne(warned.text, quiet.text)
		var gaze: DialogueLine = await _line(resource, context, "gaze")
		var tags: PackedStringArray = []
		for response: DialogueResponse in gaze.responses:
			tags.append_array(response.tags)
		assert_has(tags, "hon")
		assert_has(tags, "prs")
		assert_has(tags, "lie")
		assert_has(tags, "thr")
		assert_eq(awareness.rule_exposure[DEF_NpcTrait.Kind.GAZE_AVERSION], 2.0)
		assert_eq(awareness.warned_rules, [DEF_NpcTrait.Kind.GAZE_AVERSION])
		assert_eq(SaveDataCodec.encode(person), snapshot)
		context.end()
		assert_false(context.gaze_warning_given(), "A closed context cannot read a later session")
	assert_ne(quiet_lines[0], quiet_lines[1])
	assert_ne(warned_lines[0], warned_lines[1])


func test_shy_customer_variants_keep_scanning_guard_and_read_the_same_warning_owner() -> void:
	var person: NpcRecord = _shy_person()
	var body: E_DistrictNpc = _stage(person)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	for index: int in person.profile.dialogue_variants.size():
		var visit: CustomerVisit = _case(person, "shy/unregistered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		var resource: DialogueResource = _resource(person.profile.dialogue_variants[index])
		var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		for repeat: int in range(2):
			var line: DialogueLine = await _line(resource, context, "direct")
			assert_true(line.text.to_lower().contains("просканир"))
			assert_eq(line.responses.size(), 0)
			assert_eq(SaveDataCodec.encode(visit), before)
		awareness.warned_rules.clear()
		assert_false(context.gaze_warning_given())
		awareness.warned_rules.append(DEF_NpcTrait.Kind.GAZE_AVERSION)
		assert_true(context.gaze_warning_given())
		context.end()
		NpcServiceRole.release(body, visit.visit_id)


func test_shy_customer_registered_denial_reuses_the_existing_idempotent_outcome() -> void:
	var person: NpcRecord = _shy_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in person.profile.dialogue_variants.size():
		var visit: CustomerVisit = _delivery_case(person, "shy/registered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		var resource: DialogueResource = _resource(person.profile.dialogue_variants[index])
		var direct: DialogueLine = await _line(resource, context, "direct")
		assert_gt(direct.responses.size(), 0)
		assert_true(direct.text.contains(context.package_number_text()))
		var denial: DialogueLine = await _line(resource, context, "deny_honest")
		while denial != null:
			denial = await resource.get_next_dialogue_line(denial.next_id, [{ "ctx": context }])
		assert_eq(visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
		assert_eq(visit.player_denial_count, 1)
		assert_false(context.commit_denial())
		assert_eq(visit.player_denial_count, 1)
		context.end()
		NpcServiceRole.release(body, visit.visit_id)
#endregion
