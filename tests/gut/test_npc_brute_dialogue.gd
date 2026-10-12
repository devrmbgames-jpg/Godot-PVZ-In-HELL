extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Brute variants read recognized strength, retain role transactions and native panel lifetimes.

const BRUTE_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_brute.tres"
)


#region Native brute fixture
func _brute_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = BRUTE_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _remember_strength(person: NpcRecord, body: E_DistrictNpc, incident: StringName) -> void:
	NpcSocialService.remember(
		person,
		_player,
		body,
		NpcMemory.Kind.ATTACK,
		incident,
		NpcMemory.Reaction.RESPECT,
	)


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


#region Imported content and recognized strength
func test_brute_variants_preserve_role_cues_threat_tags_private_goods_and_saved_selection() -> void:
	var person: NpcRecord = _brute_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(BRUTE_PROFILE.valid_rules())
	assert_eq(BRUTE_PROFILE.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_eq(context.dialogue_cue(), "provocation")
	var greetings: Array[String] = []
	var arguments: Array[String] = []
	for path: String in BRUTE_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var greeting: DialogueLine = await _line(resource, context, context.dialogue_cue())
		assert_eq(greeting.character, person.display_name)
		greetings.append(greeting.text)
		var strength: DialogueLine = await _line(resource, context, "strength")
		arguments.append(strength.text)
		assert_eq(strength.responses.size(), 5)
		for index: int in range(5):
			assert_true(
				(
					strength.responses[index] as DialogueResponse
				).has_tag(["hon", "prs", "thr", "sub", "lie"][index])
			)
		var goods: DialogueLine = await _line(resource, context, "goods")
		assert_string_contains(goods.text.to_lower(), "оружие")
		var privacy: DialogueLine = await _line(resource, context, "privacy")
		assert_string_contains(privacy.text.to_lower(), "игрушку")
		for cue: String in ["weapon", "restraint", "bluff", "neighborhood"]:
			assert_not_null(await _line(resource, context, cue))
	assert_ne(greetings[0], greetings[1])
	assert_ne(arguments[0], arguments[1])
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	assert_eq(restored.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(restored.display_name, person.display_name)
	for repeat: int in range(3):
		assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	assert_eq(SaveDataCodec.encode(person), saved)
	context.end()


func test_both_roles_read_actor_specific_respect_without_mutating_memory_visit_or_combat() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _brute_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_false(context.respects_player())
	var ordinary: Array[String] = []
	for path: String in BRUTE_PROFILE.dialogue_variants:
		ordinary.append((await _line(_resource(path), context, "street")).text)
	var stranger: Entity = Entity.new()
	var identity: C_NpcIdentity = C_NpcIdentity.new()
	identity.npc_id = &"brute/stranger"
	stranger.component_resources = [identity]
	_world.add_entity(stranger)
	NpcSocialService.remember(
		person,
		stranger,
		body,
		NpcMemory.Kind.ATTACK,
		&"brute/other",
		NpcMemory.Reaction.RESPECT,
	)
	assert_false(context.respects_player())
	_remember_strength(person, body, &"brute/player")
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	for index: int in BRUTE_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(BRUTE_PROFILE.dialogue_variants[index])
		for repeat: int in range(2):
			assert_true(context.respects_player())
			var greeting: DialogueLine = await _line(resource, context, "street")
			assert_ne(greeting.text, ordinary[index])
			if index == 1:
				assert_string_contains(
					(await _line(resource, context, "restraint")).text.to_lower(),
					"уважаю",
				)
			else:
				assert_string_contains(greeting.text, "силу")
	assert_eq(SaveDataCodec.encode(person), saved)
	assert_null(CombatQueries.target_for(body))
	context.end()
	assert_false(context.respects_player())
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	_district.people[0] = restored
	for index: int in BRUTE_PROFILE.dialogue_variants.size():
		var visit: CustomerVisit = _delivery_case(restored, "brute/respect/%d" % index)
		var service: CustomerDialogueContext = _service_context(body, visit)
		var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		var resource: DialogueResource = _resource(BRUTE_PROFILE.dialogue_variants[index])
		for repeat: int in range(2):
			assert_true(service.respects_player())
			var greeting: DialogueLine = await _line(resource, service, "direct")
			assert_string_contains(greeting.text, service.package_number_text())
			assert_string_contains(greeting.text.to_lower(), "силу" if index == 0 else "помню")
		var strength: DialogueLine = await _line(resource, service, "strength")
		var submission: DialogueResponse = strength.responses[3] as DialogueResponse
		assert_false(submission.is_allowed, "Service choices do not offer surrender")
		assert_eq(SaveDataCodec.encode(visit), before)
		assert_eq(SaveDataCodec.encode(restored), saved)
		assert_null(CombatQueries.target_for(body))
		service.end()
		assert_false(service.respects_player())
		NpcServiceRole.release(body, visit.visit_id)


func test_honest_response_cannot_grant_strength_and_actual_submission_overrides_memory() -> void:
	var person: NpcRecord = _brute_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var resource: DialogueResource = _resource(person.variation.dialogue_path)
	var strength: DialogueLine = await _line(resource, context, "strength")
	assert_true(context.apply_response_tags((strength.responses[0] as DialogueResponse).tags))
	assert_false(context.respects_player())
	_remember_strength(person, body, &"brute/established_strength")
	assert_true(context.respects_player())
	var submission: DialogueResponse = strength.responses[3] as DialogueResponse
	assert_true(submission.is_allowed)
	assert_true(context.apply_response_tags(submission.tags))
	assert_eq(person.memories.back().kind, NpcMemory.Kind.SUBMISSION)
	assert_false(NpcPrideRules.respects(person, &"player"))
	var restored: NpcRecord = SaveDataCodec.decode(SaveDataCodec.encode(person)) as NpcRecord
	assert_false(NpcPrideRules.respects(restored, &"player"))
	context.end()
	assert_false(context.respects_player())
	var legacy: Entity = Entity.new()
	_world.add_entity(legacy)
	assert_false(NpcDialogueService.has_respect_for(legacy, _player))
	assert_false(NpcDialogueService.has_respect_for(null, _player))
#endregion


#region Registered service and private delivery authority
func test_unregistered_variants_require_scan_and_registered_denial_commits_once() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _brute_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in BRUTE_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(BRUTE_PROFILE.dialogue_variants[index])
		var memories_before: int = person.memories.size()
		var visit: CustomerVisit = _case(person, "brute/unregistered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		assert_eq(context.dialogue_cue(), "provocation")
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
		visit = _delivery_case(person, "brute/denial/%d" % index)
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


func test_brute_variants_keep_private_home_delivery_acceptance_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = BRUTE_PROFILE
		person.variation = NpcVariationRules.create(BRUTE_PROFILE, 1234, person.npc_id, 1)
		person.variation.dialogue_path = BRUTE_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "brute/delivery/%d" % index)
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
func test_native_panels_read_respect_in_both_roles_and_release_focus_without_mutation() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _brute_person()
	var body: E_DistrictNpc = _stage(person)
	_remember_strength(person, body, &"brute/panel_strength")
	for index: int in BRUTE_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = BRUTE_PROFILE.dialogue_variants[index]
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
		var visit: CustomerVisit = _delivery_case(person, "brute/panel/%d" % index)
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
