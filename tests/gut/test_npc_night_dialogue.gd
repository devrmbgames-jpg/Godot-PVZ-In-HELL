extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Personal hunting dialogue reads sampled light and preserves real role transactions.

const NIGHT_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_night_hunter.tres"
)


#region Personal night fixture
func _night_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = NIGHT_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _perceived_darkness(awareness: C_NpcAwareness, dark: bool) -> void:
	awareness.player_visible = true
	awareness.self_light_exposure = 0.1 if dark else 1.0
	awareness.player_light_exposure = 0.1 if dark else 1.0
#endregion


#region Imported content and committed identity
func test_night_imports_preserve_role_cues_and_persistent_variant_selection() -> void:
	var person: NpcRecord = _night_person()
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


#region Read-only light views and native role flows
func test_both_street_tones_read_shared_light_without_combat_or_memory_mutation() -> void:
	var person: NpcRecord = _night_person()
	var body: E_DistrictNpc = _stage(person)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var quiet_lines: Array[String] = []
	var hunting_lines: Array[String] = []
	for path: String in person.profile.dialogue_variants:
		var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
		assert_true(context.begin())
		var resource: DialogueResource = _resource(path)
		var snapshot: Dictionary = SaveDataCodec.encode(person) as Dictionary
		_perceived_darkness(awareness, false)
		assert_false(context.player_in_hunting_darkness())
		quiet_lines.append((await _line(resource, context, "street")).text)
		_perceived_darkness(awareness, true)
		assert_true(context.player_in_hunting_darkness())
		hunting_lines.append((await _line(resource, context, "street")).text)
		assert_ne(hunting_lines.back(), quiet_lines.back())
		var light: DialogueLine = await _line(resource, context, "light")
		var tags: PackedStringArray = []
		for response: DialogueResponse in light.responses:
			tags.append_array(response.tags)
		for expected: String in ["hon", "prs", "lie", "thr"]:
			assert_has(tags, expected)
		assert_eq(awareness.self_light_exposure, 0.1)
		assert_eq(awareness.player_light_exposure, 0.1)
		assert_true(awareness.player_visible)
		assert_eq(SaveDataCodec.encode(person), snapshot)
		assert_null(CombatQueries.target_for(body))
		assert_false(awareness.reacted_rules.has(DEF_NpcTrait.Kind.DARK_PREDATOR))
		awareness.player_visible = false
		assert_false(context.player_in_hunting_darkness(), "Hidden positions are not inferred")
		awareness.player_visible = true
		awareness.player_light_exposure = 1.0
		assert_false(context.player_in_hunting_darkness())
		awareness.player_light_exposure = 0.1
		awareness.self_light_exposure = 1.0
		assert_false(context.player_in_hunting_darkness())
		awareness.self_light_exposure = 0.3
		awareness.player_light_exposure = 0.3
		assert_false(context.player_in_hunting_darkness(), "The hunt threshold remains authored")
		awareness.self_light_exposure = 0.25
		awareness.player_light_exposure = 0.25
		assert_true(context.player_in_hunting_darkness())
		context.end()
		assert_false(context.player_in_hunting_darkness(), "Closed contexts reject later state")
	assert_ne(quiet_lines[0], quiet_lines[1])
	assert_ne(hunting_lines[0], hunting_lines[1])


func test_customer_light_view_keeps_unregistered_scanning_guard_without_outcome_mutation() -> void:
	var person: NpcRecord = _night_person()
	var body: E_DistrictNpc = _stage(person)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	for index: int in person.profile.dialogue_variants.size():
		var visit: CustomerVisit = _case(person, "night/unregistered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		var resource: DialogueResource = _resource(person.profile.dialogue_variants[index])
		var snapshot: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		for repeat: int in range(2):
			var direct: DialogueLine = await _line(resource, context, "direct")
			assert_true(direct.text.to_lower().contains("просканир"))
			assert_eq(direct.responses.size(), 0)
			assert_eq(SaveDataCodec.encode(visit), snapshot)
		_perceived_darkness(awareness, false)
		assert_false(context.player_in_hunting_darkness())
		var quiet: DialogueLine = await _line(resource, context, "light")
		_perceived_darkness(awareness, true)
		assert_true(context.player_in_hunting_darkness())
		var hunting: DialogueLine = await _line(resource, context, "light")
		assert_ne(hunting.text, quiet.text)
		assert_eq(SaveDataCodec.encode(visit), snapshot)
		assert_null(CombatQueries.target_for(body))
		context.end()
		assert_false(context.player_in_hunting_darkness())
		NpcServiceRole.release(body, visit.visit_id)


func test_night_registered_denial_commits_the_existing_outcome_once() -> void:
	var person: NpcRecord = _night_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in person.profile.dialogue_variants.size():
		var visit: CustomerVisit = _delivery_case(person, "night/registered/%d" % index)
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


func test_both_night_variants_keep_street_and_service_personal_delivery_acceptance() -> void:
	var archetype: DEF_NpcArchetype = NIGHT_PROFILE
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = archetype
		person.variation = NpcVariationRules.create(archetype, 1234, person.npc_id, 1)
		person.variation.dialogue_path = archetype.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "night/delivery/%d" % index)
		var job: NpcHomeDelivery = HomeDeliveryQueries.personal_for(person.npc_id, visit.visit_id)
		assert_not_null(job)
		if job == null:
			return
		var body: E_DistrictNpc = _stage(person)
		var context: NpcDialogueContext
		var cue: String
		if index % 2 == 0:
			context = NpcStreetDialogueContext.new(_player, body)
			assert_true(context.begin())
			cue = "delivery_request"
		else:
			context = _service_context(body, visit)
			cue = "home_request"
		var resource: DialogueResource = _resource(person.variation.dialogue_path)
		var prompt: DialogueLine = await _line(resource, context, cue)
		assert_string_contains(prompt.text, context.delivery_address())
		for step: int in range(3):
			if not prompt.responses.is_empty():
				break
			prompt = await _line(resource, context, prompt.next_id)
		assert_false(prompt.responses.is_empty())
		var accept: DialogueResponse = prompt.responses[0] as DialogueResponse
		assert_null(await _line(resource, context, accept.next_id))
		assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
		assert_true(NpcDeliveryOfferService.accept(job.job_id))
		assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
		assert_false(job.published)
		assert_not_null(PackageQueries.find_live_package(visit.package_id))
		context.end()


func test_darkness_view_is_absent_for_legacy_or_missing_dialogue_capabilities() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = _stage(person)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	_perceived_darkness(awareness, true)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_false(context.player_in_hunting_darkness())
	assert_false(NpcDarknessQueries.player_in_hunting_darkness(_player))
	assert_false(NpcDarknessQueries.player_in_hunting_darkness(null))
	context.end()
#endregion
