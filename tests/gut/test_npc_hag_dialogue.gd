extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Native hag riddles share visit outcomes, personal memory and existing role/modal lifetimes.

const HAG_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_hag.tres"
)


#region Native hag fixture
func _hag_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = HAG_PROFILE
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


func _after_choice(panel: CustomerDialoguePanel, previous_id: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		var line: DialogueLine = panel.get("_line") as DialogueLine
		if line != null and line.id != previous_id and not panel.get("_advancing"):
			return
		await get_tree().process_frame
	fail_test("The native panel did not advance the selected response")
#endregion


#region Imported content and personal memory
func test_hag_variants_preserve_role_cues_distinct_topics_tags_and_saved_selection() -> void:
	var person: NpcRecord = _hag_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(HAG_PROFILE.valid_rules())
	assert_eq(HAG_PROFILE.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_eq(context.dialogue_cue(), "provocation")
	var greetings: Array[String] = []
	var questions: Array[String] = []
	for path: String in HAG_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var greeting: DialogueLine = await _line(resource, context, context.dialogue_cue())
		assert_eq(greeting.character, person.display_name)
		greetings.append(greeting.text)
		questions.append((await _line(resource, context, "street_riddle")).text)
		var tricks: DialogueLine = await _line(resource, context, "tricks")
		for index: int in range(4):
			assert_true(
				(
					tricks.responses[index] as DialogueResponse
				).has_tag(["hon", "prs", "lie", "thr"][index])
			)
		var goods: DialogueLine = await _line(resource, context, "goods")
		assert_string_contains(goods.text.to_lower(), "реагент")
		assert_string_contains(goods.text.to_lower(), "артефакт")
		for cue: String in ["reagents", "artifact", "restraint", "neighborhood"]:
			assert_not_null(await _line(resource, context, cue))
	assert_ne(greetings[0], greetings[1])
	assert_ne(questions[0], questions[1])
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	assert_eq(restored.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(restored.display_name, person.display_name)
	for repeat: int in range(3):
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	assert_eq(SaveDataCodec.encode(person), saved)
	context.end()


func test_both_roles_read_personal_grudge_without_mutating_memory_or_visit() -> void:
	var person: NpcRecord = _hag_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_false(context.holds_grudge())
	var ordinary: Array[String] = []
	for path: String in HAG_PROFILE.dialogue_variants:
		ordinary.append((await _line(_resource(path), context, "street")).text)
	NpcSocialService.remember(person, _player, body, NpcMemory.Kind.LIE, &"hag/personal")
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	for index: int in HAG_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(HAG_PROFILE.dialogue_variants[index])
		var greeting: DialogueLine = await _line(resource, context, "street")
		assert_true(context.holds_grudge())
		assert_ne(greeting.text, ordinary[index])
		assert_string_contains(greeting.text.to_lower(), "обид")
		assert_string_contains(
			(await _line(resource, context, "caught_lie")).text,
			"Опять" if index == 1 else "Снова",
		)
	assert_eq(SaveDataCodec.encode(person), saved)
	context.end()
	assert_false(context.holds_grudge())
	for index: int in HAG_PROFILE.dialogue_variants.size():
		var visit: CustomerVisit = _case(person, "hag/grudge/%d" % index)
		visit.definition = DEF_Customer.new()
		var service: CustomerDialogueContext = _service_context(body, visit)
		visit.riddle_solved = false
		var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		var resource: DialogueResource = _resource(HAG_PROFILE.dialogue_variants[index])
		for repeat: int in range(2):
			assert_true(service.holds_grudge())
			var question: DialogueLine = await _line(resource, service, service.dialogue_cue())
			assert_string_contains(question.text.to_lower(), "обид")
		assert_eq(SaveDataCodec.encode(visit), before)
		assert_eq(SaveDataCodec.encode(person), saved)
		assert_null(CombatQueries.target_for(body))
		service.end()
		assert_false(service.holds_grudge())
		NpcServiceRole.release(body, visit.visit_id)


func test_street_riddles_explain_correct_wrong_and_joke_without_service_outcomes() -> void:
	var person: NpcRecord = _hag_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	for path: String in HAG_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		var question: DialogueLine = await _line(resource, context, "street_riddle")
		assert_eq(question.responses.size(), 4)
		assert_true((question.responses[0] as DialogueResponse).has_tag("hon"))
		assert_true((question.responses[2] as DialogueResponse).has_tag("jok"))
		assert_true((question.responses[3] as DialogueResponse).has_tag("lie"))
		assert_true((question.responses[1] as DialogueResponse).tags.is_empty())
		for index: int in range(3):
			var explanation: DialogueLine = await _line(
				resource,
				context,
				(question.responses[index] as DialogueResponse).next_id,
			)
			assert_not_null(explanation)
			assert_null(await _line(resource, context, explanation.next_id))
	assert_eq(SaveDataCodec.encode(person), saved)
	assert_null(body.get_component(C_CustomerAgent))
	context.end()
#endregion


#region Authoritative service transactions
func test_service_wrong_answer_penalty_and_correct_resolution_commit_once_per_visit() -> void:
	var person: NpcRecord = _hag_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in HAG_PROFILE.dialogue_variants.size():
		var visit: CustomerVisit = _delivery_case(person, "hag/riddle/%d" % index)
		var context: CustomerDialogueContext = _service_context(body, visit)
		visit.riddle_solved = false
		assert_eq(context.dialogue_cue(), "riddle")
		var resource: DialogueResource = _resource(HAG_PROFILE.dialogue_variants[index])
		var question: DialogueLine = await _line(resource, context, context.dialogue_cue())
		var wrong: DialogueResponse = question.responses[1] as DialogueResponse
		assert_true(wrong.tags.is_empty(), "An incorrect guess is not a lie")
		assert_true(context.apply_response_tags(wrong.tags))
		for repeat: int in range(2):
			var failure: DialogueLine = await _line(resource, context, wrong.next_id)
			assert_eq(failure.responses.size(), 2)
			assert_true(visit.riddle_wrong_answer_applied)
			assert_false(visit.riddle_solved)
			assert_eq(
				visit.dialogue_satisfaction_delta,
				-visit.definition.riddle_wrong_satisfaction_penalty,
			)
			assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
			question = await _line(
				resource,
				context,
				(failure.responses[0] as DialogueResponse).next_id,
			)
		var correct: DialogueResponse = question.responses[0] as DialogueResponse
		assert_true(correct.has_tag("hon"))
		for repeat: int in range(2):
			var success: DialogueLine = await _line(resource, context, correct.next_id)
			assert_not_null(success)
			assert_true(visit.riddle_solved)
			assert_true(visit.riddle_wrong_answer_applied)
			var direct: DialogueLine = await _line(resource, context, success.next_id)
			assert_string_contains(direct.text, context.package_number_text())
			assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
			assert_eq(
				visit.dialogue_satisfaction_delta,
				-visit.definition.riddle_wrong_satisfaction_penalty,
			)
		assert_ne(context.dialogue_cue(), "riddle")
		assert_eq(person.memories.size(), 0)
		context.end()
		assert_false(context.answer_riddle_correct())
		NpcServiceRole.release(body, visit.visit_id)


func test_solved_unregistered_riddle_keeps_scan_guard_and_registered_denial_commits_once() -> void:
	var person: NpcRecord = _hag_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in HAG_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(HAG_PROFILE.dialogue_variants[index])
		var visit: CustomerVisit = _case(person, "hag/unregistered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		visit.riddle_solved = false
		var success: DialogueLine = await _line(resource, context, "riddle_correct")
		var direct: DialogueLine = await _line(resource, context, success.next_id)
		assert_false(context.has_registered_number())
		assert_string_contains(direct.text.to_lower(), "просканируйте")
		assert_false(direct.text.contains("---"))
		assert_eq(direct.responses.size(), 0)
		assert_null(await _line(resource, context, direct.next_id))
		assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
		assert_eq(visit.player_denial_count, 0)
		context.end()
		NpcServiceRole.release(body, visit.visit_id)
		visit = _delivery_case(person, "hag/denial/%d" % index)
		context = _service_context(body, visit)
		assert_true(context.has_registered_number())
		direct = await _line(resource, context, context.dialogue_cue())
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


func test_hag_variants_keep_private_home_delivery_acceptance_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = HAG_PROFILE
		person.variation = NpcVariationRules.create(HAG_PROFILE, 1234, person.npc_id, 1)
		person.variation.dialogue_path = HAG_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "hag/delivery/%d" % index)
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
func test_native_panels_route_street_provocation_and_service_riddle_and_release_modal() -> void:
	var person: NpcRecord = _hag_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in HAG_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = HAG_PROFILE.dialogue_variants[index]
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
		var visit: CustomerVisit = _case(person, "hag/panel/%d" % index)
		visit.definition = DEF_Customer.new()
		NpcServiceRole.begin(body, person, visit, 1)
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		assert_false(visit.riddle_solved)
		assert_true(DialoguePanelRouter.open_customer(_player, body, agent))
		panel = await _ready_panel()
		var question: DialogueLine = panel.get("_line") as DialogueLine
		assert_eq(question.responses.size(), 4)
		assert_eq(visit.dialogue_satisfaction_delta, 0)
		assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
		assert_eq(
			(panel.get("_resource") as DialogueResource).resource_path,
			person.variation.dialogue_path,
		)
		panel.call("_on_response_pressed", question.responses[1])
		await _after_choice(panel, question.id)
		assert_true(visit.riddle_wrong_answer_applied)
		assert_false(visit.riddle_solved)
		assert_eq(
			visit.dialogue_satisfaction_delta,
			-visit.definition.riddle_wrong_satisfaction_penalty,
		)
		assert_eq(person.memories.size(), 0)
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
