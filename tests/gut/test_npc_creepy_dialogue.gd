extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Creepy variants read personal recognition while retaining both role and delivery authorities.

const CREEPY_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_creepy.tres"
)


#region Native fire fixture
func _creepy_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = CREEPY_PROFILE
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


#region Imported creepy topics and durable notice
func test_creepy_variants_preserve_role_cues_tags_and_saved_selection() -> void:
	var person: NpcRecord = _creepy_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(CREEPY_PROFILE.valid_rules())
	assert_eq(CREEPY_PROFILE.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var greetings: Array[String] = []
	var questions: Array[String] = []
	for path: String in CREEPY_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var greeting: DialogueLine = await _line(resource, context, context.dialogue_cue())
		assert_eq(greeting.character, person.display_name)
		greetings.append(greeting.text)
		var noticed: DialogueLine = await _line(resource, context, "noticed")
		assert_eq(noticed.responses.size(), 5)
		for index: int in range(5):
			var response: DialogueResponse = noticed.responses[index] as DialogueResponse
			assert_true(response.has_tag(["prs", "lie", "thr", "jok", "hon"][index]))
		var question: DialogueLine = await _line(resource, context, "questions")
		questions.append(question.text)
		assert_true((question.responses[3] as DialogueResponse).has_tag("flr"))
		for cue: String in ["habits", "goods", "distance", "bluff", "humor", "affection"]:
			assert_not_null(await _line(resource, context, cue))
	assert_ne(greetings[0], greetings[1])
	assert_ne(questions[0], questions[1])
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	assert_eq(restored.variation.dialogue_path, person.variation.dialogue_path)
	for repeat: int in range(3):
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	assert_eq(SaveDataCodec.encode(person), saved)
	context.end()


func test_both_roles_read_actor_specific_notice_without_creating_detection_or_motion() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _creepy_person()
	var body: E_DistrictNpc = _stage(person)
	var memory: NpcMemory = NpcMemory.new()
	memory.kind = NpcMemory.Kind.STALKING_NOTICED
	memory.reaction = NpcMemory.Reaction.TALK
	memory.actor_id = &"another/player"
	memory.victim_id = person.npc_id
	memory.incident_id = NpcStalkingRules.incident(person, memory.actor_id)
	person.memories.append(memory)
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	for index: int in CREEPY_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(CREEPY_PROFILE.dialogue_variants[index])
		for service_role: bool in [false, true]:
			var visit: CustomerVisit = null
			var context: NpcDialogueContext
			if service_role:
				visit = _delivery_case(person, "creepy/read/%d" % index)
				context = _service_context(body, visit)
			else:
				context = NpcStreetDialogueContext.new(_player, body)
				assert_true(context.begin())
			for recognized: bool in [false, true]:
				memory.actor_id = (
					NpcSocialService.identity_for(_player) if recognized else &"another/player"
				)
				memory.incident_id = NpcStalkingRules.incident(person, memory.actor_id)
				var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
				var visit_before: Variant = SaveDataCodec.encode(visit)
				var position: Vector3 = body.global_position
				var episode: int = state.episode_sequence
				var observed: bool = state.observed
				for repeat: int in range(2):
					assert_eq(context.stalking_noticed(), recognized)
					var line: DialogueLine = await _line(resource, context, "noticed")
					assert_eq(line.text.contains("уже заметил"), recognized)
					for cue: String in ["questions", "habits", "goods", "distance"]:
						assert_not_null(await _line(resource, context, cue))
				assert_eq(SaveDataCodec.encode(person), saved)
				assert_eq(SaveDataCodec.encode(visit), visit_before)
				assert_eq(body.global_position, position)
				assert_eq(state.episode_sequence, episode)
				assert_eq(state.observed, observed)
				assert_null(CombatQueries.target_for(body))
			context.end()
			assert_false(context.stalking_noticed())
			if service_role:
				NpcServiceRole.release(body, visit.visit_id)
#endregion


#region Registered service and private delivery authority
func test_unregistered_variants_require_scan_and_registered_denial_commits_once() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _creepy_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in CREEPY_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(CREEPY_PROFILE.dialogue_variants[index])
		var memories_before: int = person.memories.size()
		var visit: CustomerVisit = _case(person, "creepy/unregistered/%d" % index)
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
		visit = _delivery_case(person, "creepy/denial/%d" % index)
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


func test_creepy_variants_preserve_private_home_delivery_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = CREEPY_PROFILE
		person.variation = NpcVariationRules.create(CREEPY_PROFILE, 1234, person.npc_id, 1)
		person.variation.dialogue_path = CREEPY_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "creepy/delivery/%d" % index)
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
func test_creepy_panels_release_focus_and_preserve_visit_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _creepy_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in CREEPY_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = CREEPY_PROFILE.dialogue_variants[index]
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
		var visit: CustomerVisit = _delivery_case(person, "creepy/panel/%d" % index)
		visit.riddle_solved = true
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
