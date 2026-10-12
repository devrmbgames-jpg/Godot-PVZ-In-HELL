extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Fire variants preserve delivery authority and never decide ignition through conversation.

const FIRE_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_fire_elemental.tres"
)


#region Native fire fixture
func _fire_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = FIRE_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _ready_panel() -> CustomerDialoguePanel:
	var panels: Array[Node] = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
	assert_eq(panels.size(), 1)
	var panel: CustomerDialoguePanel = panels[0] as CustomerDialoguePanel
	var deadline: int = Time.get_ticks_msec() + 2000
	while panel.get("_line") == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_not_null(panel.get("_line"))
	return panel
#endregion


#region Imported fire topics and saved choice
func test_fire_variants_preserve_role_cues_tags_and_saved_selection() -> void:
	var person: NpcRecord = _fire_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(FIRE_PROFILE.valid_rules())
	assert_eq(FIRE_PROFILE.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var greetings: Array[String] = []
	var openings: Array[String] = []
	for path: String in FIRE_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var greeting: DialogueLine = await _line(resource, context, context.dialogue_cue())
		assert_eq(greeting.character, person.display_name)
		greetings.append(greeting.text)
		var heat: DialogueLine = await _line(resource, context, "heat")
		assert_string_contains(heat.text, "10")
		assert_eq(heat.responses.size(), 5)
		for index: int in range(5):
			var response: DialogueResponse = heat.responses[index] as DialogueResponse
			assert_true(response.has_tag(["hon", "prs", "lie", "thr", "jok"][index]))
		var opening: DialogueLine = await _line(resource, context, "opening")
		openings.append(opening.text)
		assert_eq(opening.responses.size(), 4)
		assert_true((opening.responses[2] as DialogueResponse).has_tag("flr"))
		for cue: String in ["goods", "reagent", "caution", "affection", "bluff", "neighbors"]:
			assert_not_null(await _line(resource, context, cue))
	assert_ne(greetings[0], greetings[1])
	assert_ne(openings[0], openings[1])
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	assert_eq(restored.variation.dialogue_path, person.variation.dialogue_path)
	for repeat: int in range(3):
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	assert_eq(SaveDataCodec.encode(person), saved)
	context.end()


func test_fire_topics_in_both_roles_do_not_roll_or_repeat_committed_explosion() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _fire_person()
	var body: E_DistrictNpc = _stage(person)
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	for index: int in FIRE_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(FIRE_PROFILE.dialogue_variants[index])
		var street: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
		assert_true(street.begin())
		for cue: String in ["heat", "opening", "goods", "affection", "caution"]:
			assert_not_null(await _line(resource, street, cue))
		assert_eq(SaveDataCodec.encode(person), saved)
		assert_null(CombatQueries.target_for(body))
		street.end()
		var visit: CustomerVisit = _delivery_case(person, "fire/read_only/%d" % index)
		var service: CustomerDialogueContext = _service_context(body, visit)
		for decided: bool in [false, true]:
			visit.fire_opening_decided = decided
			visit.fire_opening_explosion = decided
			var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
			for repeat: int in range(2):
				for cue: String in ["direct", "heat", "opening", "goods", "affection", "caution"]:
					assert_not_null(await _line(resource, service, cue))
			assert_eq(SaveDataCodec.encode(visit), before)
			assert_eq(SaveDataCodec.encode(person), saved)
			assert_null(CombatQueries.target_for(body))
			assert_eq(_world.query.with_all([C_Hazard]).execute().size(), 0)
		service.end()
		NpcServiceRole.release(body, visit.visit_id)
#endregion


#region Registered service and private delivery authority
func test_unregistered_variants_require_scan_and_registered_denial_commits_once() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _fire_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in FIRE_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(FIRE_PROFILE.dialogue_variants[index])
		var memories_before: int = person.memories.size()
		var visit: CustomerVisit = _case(person, "fire/unregistered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		for repeat: int in range(2):
			var direct: DialogueLine = await _line(resource, context, context.dialogue_cue())
			assert_false(context.has_registered_number())
			assert_string_contains(direct.text, "просканируйте")
			assert_false(direct.text.contains("---"))
			assert_eq(direct.responses.size(), 0)
			assert_null(await _line(resource, context, direct.next_id))
		assert_eq(SaveDataCodec.encode(visit), before)
		assert_eq(person.memories.size(), memories_before)
		context.end()
		NpcServiceRole.release(body, visit.visit_id)
		visit = _delivery_case(person, "fire/denial/%d" % index)
		context = _service_context(body, visit)
		assert_true(context.has_registered_number())
		var direct: DialogueLine = await _line(resource, context, context.dialogue_cue())
		assert_string_contains(direct.text, context.package_number_text())
		var denial: DialogueLine = await _line(resource, context, "deny_honest")
		while denial != null:
			denial = await _line(resource, context, denial.next_id)
		assert_eq(visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
		assert_eq(visit.player_denial_count, 1)
		assert_false(context.commit_denial())
		assert_eq(visit.player_denial_count, 1)
		context.end()
		NpcServiceRole.release(body, visit.visit_id)


func test_fire_variants_preserve_private_home_delivery_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = FIRE_PROFILE
		person.variation = NpcVariationRules.create(FIRE_PROFILE, 1234, person.npc_id, 1)
		person.variation.dialogue_path = FIRE_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "fire/delivery/%d" % index)
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
		assert_null(
			await _line(resource, context, (prompt.responses[0] as DialogueResponse).next_id)
		)
		assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
		assert_true(NpcDeliveryOfferService.accept(job.job_id))
		assert_false(job.published)
		assert_not_null(PackageQueries.find_live_package(visit.package_id))
		context.end()
#endregion


#region Actual headless panel routing
func test_fire_panels_release_focus_and_preserve_visit_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _fire_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in FIRE_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = FIRE_PROFILE.dialogue_variants[index]
		var previous_focus: int = InteractionControlFocus.current(_player)
		var previous_mouse: Input.MouseMode = Input.mouse_mode
		var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
		assert_true(DialoguePanelRouter.open_street(_player, body))
		var panel: CustomerDialoguePanel = await _ready_panel()
		var greeting: DialogueLine = panel.get("_line") as DialogueLine
		assert_eq(greeting.character, person.display_name)
		assert_eq(
			(panel.get("_resource") as DialogueResource).resource_path,
			person.variation.dialogue_path,
		)
		assert_eq(InteractionControlFocus.current(_player), InteractionControlFocus.Priority.MODAL)
		assert_not_null(get_viewport().gui_get_focus_owner())
		assert_eq(SaveDataCodec.encode(person), saved)
		panel.close_dialogue()
		panel.free()
		await get_tree().process_frame
		assert_eq(InteractionControlFocus.current(_player), previous_focus)
		assert_eq(Input.mouse_mode, previous_mouse)
		assert_null(NpcDialogueService.participant(body))
		var visit: CustomerVisit = _delivery_case(person, "fire/panel/%d" % index)
		NpcServiceRole.begin(body, person, visit, 1)
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		assert_true(DialoguePanelRouter.open_customer(_player, body, agent))
		panel = await _ready_panel()
		var direct: DialogueLine = panel.get("_line") as DialogueLine
		assert_string_contains(
			direct.text,
			(panel.get("_context") as CustomerDialogueContext).package_number_text(),
		)
		assert_eq(
			(panel.get("_resource") as DialogueResource).resource_path,
			person.variation.dialogue_path,
		)
		assert_eq(SaveDataCodec.encode(visit), before)
		assert_eq(SaveDataCodec.encode(person), saved)
		panel.close_dialogue()
		panel.close_dialogue()
		panel.free()
		await get_tree().process_frame
		assert_eq(InteractionControlFocus.current(_player), previous_focus)
		assert_eq(Input.mouse_mode, previous_mouse)
		assert_null(NpcDialogueService.participant(body))
		assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
		NpcServiceRole.release(body, visit.visit_id)
#endregion
