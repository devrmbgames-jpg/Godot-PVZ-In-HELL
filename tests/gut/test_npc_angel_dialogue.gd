extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Written angel variants preserve imported role transactions and the native modal lifecycle.

const ANGEL_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_weeping_angel.tres"
)


#region Native written-dialogue fixture
func _angel_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = ANGEL_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _rendered_panel() -> CustomerDialoguePanel:
	var panels: Array[Node] = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
	assert_eq(panels.size(), 1)
	var panel: CustomerDialoguePanel = panels[0] as CustomerDialoguePanel
	var deadline: int = Time.get_ticks_msec() + 2000
	while panel.get("_line") == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_not_null(panel.get("_line"))
	return panel


func _assert_written_panel(panel: CustomerDialoguePanel) -> void:
	var board: PanelContainer = panel.get("_signboard") as PanelContainer
	var writing: RichTextLabel = board.get_node("Rows/Writing") as RichTextLabel
	var caption: Label = board.get_node("Rows/Caption") as Label
	var line: DialogueLine = panel.get("_line") as DialogueLine
	assert_eq(board.scene_file_path, "res://content/ui/npc_signboard_view.tscn")
	assert_true(board.visible)
	assert_string_contains(caption.text, "табличке")
	assert_eq(writing.text, line.text)
	assert_true(writing.fit_content)
	assert_false(writing.scroll_active)
	assert_false((panel.get("_speaker") as Label).visible)
	assert_false((panel.get("_text") as RichTextLabel).visible)
	assert_eq((panel.get("_text") as RichTextLabel).text, "")
	assert_eq(InteractionControlFocus.current(_player), InteractionControlFocus.Priority.MODAL)
	assert_not_null(get_viewport().gui_get_focus_owner())
#endregion


#region Imported variants and read-only mode
func test_angel_variants_preserve_imported_role_cues_and_committed_selection() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	assert_eq(person.profile.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var greetings: Array[String] = []
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	for path: String in person.profile.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var greeting: DialogueLine = await _line(resource, context, "street")
		assert_eq(greeting.character, "Табличка")
		greetings.append(greeting.text)
		var warning: DialogueLine = await _line(resource, context, "warning")
		assert_true((warning.responses[0] as DialogueResponse).has_tag("hon"))
		assert_true((warning.responses[1] as DialogueResponse).has_tag("prs"))
		assert_true((warning.responses[2] as DialogueResponse).has_tag("lie"))
		assert_true((warning.responses[3] as DialogueResponse).has_tag("thr"))
		assert_not_null(await _line(resource, context, "artifact"))
	assert_ne(greetings[0], greetings[1])
	var saved: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(person)) as NpcRecord
	assert_eq(saved.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(saved.display_name, person.display_name)
	for repeat: int in range(3):
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	context.end()


func test_written_mode_is_a_read_only_authored_cue_shared_by_both_roles() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	var snapshot: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var street: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(street.begin())
	for repeat: int in range(3):
		assert_true(street.uses_signboard())
	assert_eq(SaveDataCodec.encode(person), snapshot)
	street.end()
	assert_false(street.uses_signboard())
	var visit: CustomerVisit = _case(person, "angel/mode")
	var service: CustomerDialogueContext = _service_context(body, visit)
	assert_true(service.uses_signboard())
	service.end()
	assert_false(service.uses_signboard())
	NpcServiceRole.release(body, visit.visit_id)
	assert_false(NpcDialogueService.uses_signboard(_player))
	assert_false(NpcDialogueService.uses_signboard(null))
	person.profile = load(LOST_PATH) as DEF_NpcArchetype
	assert_false(NpcDialogueService.uses_signboard(body))
#endregion


#region Native panel and role transitions
func test_both_written_street_panels_render_native_board_and_release_modal_focus() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	for path: String in person.profile.dialogue_variants:
		person.variation.dialogue_path = path
		var previous_focus: int = InteractionControlFocus.current(_player)
		var previous_mouse: Input.MouseMode = Input.mouse_mode
		var snapshot: Dictionary = SaveDataCodec.encode(person) as Dictionary
		assert_true(DialoguePanelRouter.open_street(_player, body))
		var panel: CustomerDialoguePanel = await _rendered_panel()
		_assert_written_panel(panel)
		assert_eq((panel.get("_resource") as DialogueResource).resource_path, path)
		assert_eq(SaveDataCodec.encode(person), snapshot)
		panel.close_dialogue()
		panel.close_dialogue()
		panel.free()
		await get_tree().process_frame
		assert_eq(InteractionControlFocus.current(_player), previous_focus)
		assert_eq(Input.mouse_mode, previous_mouse)
		assert_null(NpcDialogueService.participant(body))


func test_ordinary_person_keeps_speaker_and_text_with_the_native_board_hidden() -> void:
	var body: E_DistrictNpc = _stage(_lost_person())
	assert_true(DialoguePanelRouter.open_street(_player, body))
	var panel: CustomerDialoguePanel = await _rendered_panel()
	var line: DialogueLine = panel.get("_line") as DialogueLine
	assert_false((panel.get("_signboard") as PanelContainer).visible)
	assert_true((panel.get("_speaker") as Label).visible)
	assert_eq((panel.get("_speaker") as Label).text, line.character)
	assert_true((panel.get("_text") as RichTextLabel).visible)
	assert_eq((panel.get("_text") as RichTextLabel).text, line.text)
	panel.close_dialogue()
	panel.free()


func test_service_panels_keep_sign_mode_with_personal_or_explicit_resources() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	for explicit_path: String in ["", CustomerDialogueService.DIALOGUE_PATH]:
		var visit: CustomerVisit = _case(person, "angel/panel/" + explicit_path)
		visit.definition = DEF_Customer.new()
		visit.definition.dialogue_resource_path = explicit_path
		visit.riddle_solved = true
		NpcServiceRole.begin(body, person, visit, 1)
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		var previous_focus: int = InteractionControlFocus.current(_player)
		assert_true(DialoguePanelRouter.open_customer(_player, body, agent))
		var panel: CustomerDialoguePanel = await _rendered_panel()
		_assert_written_panel(panel)
		var expected_path: String = (
			person.variation.dialogue_path if explicit_path.is_empty() else explicit_path
		)
		assert_eq((panel.get("_resource") as DialogueResource).resource_path, expected_path)
		assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
		assert_eq(visit.player_denial_count, 0)
		panel.close_dialogue()
		panel.free()
		await get_tree().process_frame
		assert_eq(InteractionControlFocus.current(_player), previous_focus)
		NpcServiceRole.release(body, visit.visit_id)


func test_angel_service_registration_guard_and_denial_keep_existing_idempotency() -> void:
	var person: NpcRecord = _angel_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in person.profile.dialogue_variants.size():
		var resource: DialogueResource = _resource(person.profile.dialogue_variants[index])
		var unregistered: CustomerVisit = _case(person, "angel/unregistered/%d" % index)
		unregistered.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, unregistered)
		for repeat: int in range(2):
			var direct: DialogueLine = await _line(resource, context, "direct")
			assert_string_contains(direct.text.to_lower(), "просканируйте")
			assert_eq(direct.responses.size(), 0)
			assert_null(await _line(resource, context, direct.next_id))
			assert_eq(unregistered.actual, CustomerVisit.Actual.NOT_RESOLVED)
			assert_eq(unregistered.player_denial_count, 0)
		context.end()
		NpcServiceRole.release(body, unregistered.visit_id)
		var registered: CustomerVisit = _delivery_case(person, "angel/registered/%d" % index)
		registered.definition = DEF_Customer.new()
		context = _service_context(body, registered)
		assert_true(context.has_registered_number())
		var direct: DialogueLine = await _line(resource, context, "direct")
		assert_string_contains(direct.text, context.package_number_text())
		var denial: DialogueLine = await _line(resource, context, "deny_honest")
		while denial != null:
			denial = await _line(resource, context, denial.next_id)
		assert_eq(registered.actual, CustomerVisit.Actual.PLAYER_DENIED)
		assert_eq(registered.player_denial_count, 1)
		assert_false(context.commit_denial())
		assert_eq(registered.player_denial_count, 1)
		context.end()
		NpcServiceRole.release(body, registered.visit_id)


func test_both_angel_variants_keep_actual_private_delivery_acceptance_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = ANGEL_PROFILE
		person.variation = NpcVariationRules.create(ANGEL_PROFILE, 1234, person.npc_id, 1)
		person.variation.dialogue_path = ANGEL_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "angel/delivery/%d" % index)
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
		assert_true(context.uses_signboard())
		var resource: DialogueResource = _resource(person.variation.dialogue_path)
		var prompt: DialogueLine = await _line(resource, context, cue)
		assert_string_contains(prompt.text, context.delivery_address())
		for step: int in range(3):
			if not prompt.responses.is_empty():
				break
			prompt = await _line(resource, context, prompt.next_id)
		assert_false(prompt.responses.is_empty())
		assert_null(
			await _line(resource, context, (prompt.responses[0] as DialogueResponse).next_id)
		)
		assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
		assert_true(NpcDeliveryOfferService.accept(job.job_id))
		assert_false(job.published)
		assert_not_null(PackageQueries.find_live_package(visit.package_id))
		context.end()
#endregion
