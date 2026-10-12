extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Imported soul confirmations preserve durable receipts, both roles and actual panel death cleanup.

const CHAIN_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_chain_devil.tres"
)


#region Real dialogue fixture
func _chain_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = CHAIN_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	if not _player.has_component(C_SoulTrade):
		_player.add_component(C_SoulTrade.new())
	if not _player.has_component(C_Living):
		_player.add_component(C_Living.new())
	return person


func _ledger() -> C_SoulTrade:
	return _player.get_component(C_SoulTrade) as C_SoulTrade


func _health() -> C_Health:
	return _player.get_component(C_Health) as C_Health


func _strength() -> C_Strength:
	return _player.get_component(C_Strength) as C_Strength


func _due_next() -> void:
	GameTimeQueries.current().elapsed_ticks = _ledger().offers.back().next_offer_tick


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


#region Imported content and explicit acceptance
func test_chain_role_cues_distinct_topics_and_observational_greetings_preserve_selection() -> void:
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(CHAIN_PROFILE.valid_rules())
	assert_eq(CHAIN_PROFILE.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var greetings: Array[String] = []
	for path: String in CHAIN_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var before: Dictionary = SaveDataCodec.component_data(_ledger())
		var greeting: DialogueLine = await _line(resource, context, context.dialogue_cue())
		greetings.append(greeting.text)
		assert_eq(greeting.character, person.display_name)
		for cue: String in ["goods", "fire", "contract", "affection"]:
			assert_not_null(await _line(resource, context, cue))
		assert_eq(SaveDataCodec.component_data(_ledger()), before)
		assert_eq(_strength().value, 1.0)
	assert_ne(greetings[0], greetings[1])
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	assert_eq(restored.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	context.end()


func test_street_and_service_confirmation_cues_commit_once_and_replay_cannot_reverse() -> void:
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in CHAIN_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(CHAIN_PROFILE.dialogue_variants[index])
		var context: NpcDialogueContext
		var visit: CustomerVisit = null
		if index == 0:
			context = NpcStreetDialogueContext.new(_player, body)
			assert_true(context.begin())
		else:
			visit = _delivery_case(person, "chain/soul_service")
			context = _service_context(body, visit)
		var offer: DialogueLine = await _line(resource, context, "soul_offer")
		assert_eq(offer.responses.size(), 3)
		assert_eq(context.soul_strength_gain(), 1.0)
		assert_eq(context.soul_health_cost(), 10.0)
		assert_eq(context.soul_fatal_count(), 3)
		assert_string_contains(offer.text, "3")
		assert_eq(context.soul_accepted_count(), index)
		assert_eq(_ledger().offers.size(), index + 1)
		var accepted: DialogueLine = await _line(
			resource,
			context,
			(offer.responses[0] as DialogueResponse).next_id,
		)
		assert_not_null(accepted)
		assert_true(context.soul_offer_accepted())
		assert_eq(_ledger().accepted_count, index + 1)
		assert_eq(_strength().value, float(index + 2))
		assert_eq(_health().value, 100.0 - 10.0 * (index + 1))
		for repeat: int in range(3):
			assert_not_null(await _line(resource, context, "soul_accept"))
			assert_not_null(await _line(resource, context, "soul_decline"))
			assert_true(context.soul_offer_accepted())
			assert_false(context.soul_offer_declined())
			assert_eq(_ledger().accepted_count, index + 1)
		assert_not_null(await _line(resource, context, "soul_offer"))
		assert_eq(_ledger().offers.size(), index + 1)
		context.end()
		if visit != null:
			assert_false(visit.finished)
			NpcServiceRole.release(body, visit.visit_id)
		_due_next()


func test_closing_without_answer_reuses_pending_key_and_refusal_preserves_total() -> void:
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	var resource: DialogueResource = _resource(CHAIN_PROFILE.dialogue_variants[0])
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_not_null(await _line(resource, context, "soul_offer"))
	var key: StringName = _ledger().offers[0].confirmation_key
	context.end()
	assert_eq(_ledger().accepted_count, 0)
	assert_eq(_ledger().offers[0].outcome, SoulTradeRecord.Outcome.OFFERED)
	context = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_not_null(await _line(resource, context, "soul_offer"))
	assert_eq(_ledger().offers.size(), 1)
	assert_eq(_ledger().offers[0].confirmation_key, key)
	assert_not_null(await _line(resource, context, "soul_accept"))
	assert_eq(_ledger().accepted_count, 1)
	context.end()
	_due_next()
	context = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_not_null(await _line(resource, context, "soul_offer"))
	assert_not_null(await _line(resource, context, "soul_decline"))
	assert_true(context.soul_offer_declined())
	assert_eq(_ledger().accepted_count, 1)
	assert_eq(_strength().value, 2.0)
	assert_false(context.can_offer_soul())
	assert_not_null(await _line(resource, context, "soul_accept"))
	assert_false(context.soul_offer_accepted())
	assert_eq(_ledger().accepted_count, 1)
	context.end()


func test_rejected_confirmation_does_not_claim_acceptance_or_change_receipt() -> void:
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var resource: DialogueResource = _resource(CHAIN_PROFILE.dialogue_variants[1])
	assert_not_null(await _line(resource, context, "soul_offer"))
	_health().value = 10.0
	_health().base = 10.0
	_health().current = 10.0
	assert_not_null(await _line(resource, context, "soul_accept"))
	assert_false(context.soul_offer_accepted())
	assert_false(context.soul_offer_declined())
	assert_eq(_ledger().accepted_count, 0)
	assert_eq(_ledger().offers[0].outcome, SoulTradeRecord.Outcome.OFFERED)
	assert_eq(_strength().value, 1.0)
	context.end()


func test_third_panel_confirmation_uses_common_death_and_releases_modal_capture() -> void:
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	_world.add_observer(O_HealthLifecycle.new())
	var resource: DialogueResource = _resource(CHAIN_PROFILE.dialogue_variants[0])
	for prior: int in range(2):
		var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
		assert_true(context.begin())
		assert_not_null(await _line(resource, context, "soul_offer"))
		assert_not_null(await _line(resource, context, "soul_accept"))
		context.end()
		_due_next()
	person.variation.dialogue_path = CHAIN_PROFILE.dialogue_variants[0]
	var previous_focus: int = InteractionControlFocus.current(_player)
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	assert_true(DialoguePanelRouter.open_street(_player, body))
	var panel: CustomerDialoguePanel = await _ready_panel()
	panel.call("_advance", "soul_offer")
	var deadline: int = Time.get_ticks_msec() + 2000
	while bool(panel.get("_advancing")) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var offer: DialogueLine = panel.get("_line") as DialogueLine
	assert_not_null(offer)
	assert_eq(offer.responses.size(), 3)
	panel.call("_on_response_pressed", offer.responses[0])
	while is_instance_valid(panel) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_eq(_ledger().accepted_count, 3)
	assert_eq(_health().current, 0.0)
	assert_true(_player.has_component(C_Death))
	assert_null(NpcDialogueService.participant(body))
	assert_eq(InteractionControlFocus.current(_player), previous_focus)
	assert_eq(Input.mouse_mode, previous_mouse)
	assert_true(get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP).is_empty())
#endregion


#region Registered service and private delivery authority
func test_unregistered_variants_require_scan_and_registered_denial_commits_once() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in CHAIN_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(CHAIN_PROFILE.dialogue_variants[index])
		var memories_before: int = person.memories.size()
		var visit: CustomerVisit = _case(person, "chain/unregistered/%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		var before: Dictionary = SaveDataCodec.encode(visit) as Dictionary
		for repeat: int in range(2):
			var direct: DialogueLine = await _line(resource, context, context.dialogue_cue())
			assert_false(context.has_registered_number())
			assert_string_contains(direct.text.to_lower(), "сканир")
			assert_false(direct.text.contains("---"))
			assert_eq(direct.responses.size(), 0)
			assert_null(await _line(resource, context, direct.next_id))
		assert_eq(SaveDataCodec.encode(visit), before)
		assert_eq(person.memories.size(), memories_before)
		context.end()
		NpcServiceRole.release(body, visit.visit_id)
		visit = _delivery_case(person, "chain/denial/%d" % index)
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


func test_chain_variants_preserve_private_home_delivery_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = CHAIN_PROFILE
		person.variation = NpcVariationRules.create(CHAIN_PROFILE, 1234, person.npc_id, 1)
		person.variation.dialogue_path = CHAIN_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "chain/delivery/%d" % index)
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
func test_chain_panels_release_focus_and_preserve_visit_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _chain_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in CHAIN_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = CHAIN_PROFILE.dialogue_variants[index]
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
		var visit: CustomerVisit = _delivery_case(person, "chain/panel/%d" % index)
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
