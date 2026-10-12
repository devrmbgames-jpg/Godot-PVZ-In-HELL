extends "res://tests/gut/test_npc_dialogue_variants.gd"
## Imported blood confirmations retain personal keys and both real UI/service owners.

const VAMPIRE_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_vampire.tres"
)


#region Native blood fixture
func _vampire_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = VAMPIRE_PROFILE
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _health() -> C_Health:
	return _player.get_component(C_Health) as C_Health


func _due_next(person: NpcRecord) -> void:
	GameTimeQueries.current().elapsed_ticks = person.blood_offers.back().next_offer_tick


func _ready_panel() -> CustomerDialoguePanel:
	var panels: Array[Node] = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
	assert_eq(panels.size(), 1)
	var panel: CustomerDialoguePanel = panels[0] as CustomerDialoguePanel
	await _wait_panel(panel)
	assert_not_null(panel.get("_line"))
	return panel


func _wait_panel(panel: CustomerDialoguePanel) -> void:
	var deadline: int = Time.get_ticks_msec() + 2000
	while (
		(panel.get("_line") == null or bool(panel.get("_advancing")))
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().process_frame
	assert_false(bool(panel.get("_advancing")))
#endregion


#region Imported content and exact current-HP confirmation
func test_vampire_role_cues_distinct_hunger_tags_and_read_only_selection() -> void:
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(VAMPIRE_PROFILE.valid_rules())
	assert_eq(VAMPIRE_PROFILE.dialogue_variants.size(), 2)
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var greetings: Array[String] = []
	var hunger_lines: Array[String] = []
	for path: String in VAMPIRE_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_has(resource.cues, cue)
		for cue: String in service.cues:
			assert_has(resource.cues, cue)
		var before: Dictionary = SaveDataCodec.encode(person) as Dictionary
		var greeting: DialogueLine = await _line(resource, context, context.dialogue_cue())
		greetings.append(greeting.text)
		assert_eq(greeting.character, person.display_name)
		var hunger: DialogueLine = await _line(resource, context, "hunger")
		hunger_lines.append(hunger.text)
		var tags: PackedStringArray = []
		for response: DialogueResponse in hunger.responses:
			tags.append_array(response.tags)
		for expected: String in ["hon", "prs", "lie", "jok", "thr"]:
			assert_has(tags, expected)
		var goods: DialogueLine = await _line(resource, context, "goods")
		assert_true((goods.responses[0] as DialogueResponse).has_tag("flr"))
		for cue: String in ["light", "affection"]:
			assert_not_null(await _line(resource, context, cue))
		assert_eq(SaveDataCodec.encode(person), before)
		assert_true(person.blood_offers.is_empty())
		assert_eq(_health().current, 100.0)
	assert_ne(greetings[0], greetings[1])
	assert_ne(hunger_lines[0], hunger_lines[1])
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
	assert_eq(restored.variation.dialogue_path, person.variation.dialogue_path)
	assert_eq(NpcDialogueService.dialogue_path_for(body), person.variation.dialogue_path)
	context.end()


func test_both_roles_capture_percent_apply_current_hp_once_and_report_replays() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in VAMPIRE_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(VAMPIRE_PROFILE.dialogue_variants[index])
		for service_role: bool in [false, true]:
			var context: NpcDialogueContext
			var visit: CustomerVisit = null
			if service_role:
				visit = _delivery_case(person, "vampire/accept/%d" % index)
				context = _service_context(body, visit)
			else:
				context = NpcStreetDialogueContext.new(_player, body)
				assert_true(context.begin())
			_health().current = 60.0
			var offer: DialogueLine = await _line(resource, context, "blood_offer")
			var record: BloodConsentRecord = person.blood_offers.back()
			assert_eq(offer.responses.size(), 3)
			assert_string_contains(offer.text, "% от твоего текущего здоровья на момент согласия")
			assert_string_contains(offer.text, str(record.percent))
			assert_gte(record.percent, 5)
			assert_lte(record.percent, 40)
			assert_eq(context.blood_percent(), record.percent)
			_health().current = 40.0
			var expected: float = 40.0 * (1.0 - record.percent / 100.0)
			var accepted: DialogueLine = await _line(
				resource,
				context,
				(offer.responses[0] as DialogueResponse).next_id,
			)
			assert_not_null(accepted)
			assert_true(context.blood_offer_accepted())
			assert_eq(record.previous_health, 40.0)
			assert_almost_eq(_health().current, expected, 0.0001)
			assert_eq(_health().value, 100.0)
			assert_eq((_player.get_component(C_Strength) as C_Strength).value, 1.0)
			assert_false(_player.has_component(C_Death))
			var count: int = person.blood_offers.size()
			for repeat: int in range(2):
				assert_not_null(await _line(resource, context, "blood_accept"))
				var declined: DialogueLine = await _line(resource, context, "blood_decline")
				assert_string_contains(declined.text, "уже")
				assert_true(context.blood_offer_accepted())
				assert_false(context.blood_offer_declined())
				assert_almost_eq(_health().current, expected, 0.0001)
			_due_next(person)
			assert_not_null(await _line(resource, context, "blood_offer"))
			assert_eq(person.blood_offers.size(), count)
			context.end()
			if visit != null:
				assert_false(visit.finished)
				NpcServiceRole.release(body, visit.visit_id)


func test_closed_pending_offer_survives_codec_and_refusal_never_reapplies_or_accepts() -> void:
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	for path: String in VAMPIRE_PROFILE.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
		assert_true(context.begin())
		assert_not_null(await _line(resource, context, "blood_offer"))
		var record: BloodConsentRecord = person.blood_offers.back()
		var key: StringName = record.confirmation_key
		var percent: int = record.percent
		var before: float = _health().current
		context.end()
		assert_false(context.accept_blood_offer())
		assert_false(context.decline_blood_offer())
		assert_eq(record.outcome, BloodConsentRecord.Outcome.OFFERED)
		var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
		var restored: NpcRecord = SaveDataCodec.decode(saved) as NpcRecord
		_district.people[0] = restored
		person = restored
		context = NpcStreetDialogueContext.new(_player, body)
		assert_true(context.begin())
		assert_not_null(await _line(resource, context, "blood_offer"))
		assert_eq(person.blood_offers.back().confirmation_key, key)
		assert_eq(context.blood_percent(), percent)
		assert_not_null(await _line(resource, context, "blood_decline"))
		assert_true(context.blood_offer_declined())
		assert_eq(_health().current, before)
		var accepted: DialogueLine = await _line(resource, context, "blood_accept")
		assert_string_contains(accepted.text.to_lower(), "уже")
		assert_false(context.blood_offer_accepted())
		assert_true(context.blood_offer_declined())
		assert_eq(_health().current, before)
		context.end()
		_due_next(person)


func test_invalid_health_does_not_claim_acceptance_or_consume_pending_confirmation() -> void:
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var resource: DialogueResource = _resource(person.profile.dialogue_variants[1])
	assert_not_null(await _line(resource, context, "blood_offer"))
	_health().current = 101.0
	var rejected: DialogueLine = await _line(resource, context, "blood_accept")
	assert_string_contains(rejected.text, "Не получилось")
	assert_false(context.blood_offer_accepted())
	assert_false(context.blood_offer_declined())
	assert_eq(person.blood_offers[0].outcome, BloodConsentRecord.Outcome.OFFERED)
	assert_eq(_health().current, 101.0)
	_health().current = 1.0
	assert_not_null(await _line(resource, context, "blood_accept"))
	assert_true(context.blood_offer_accepted())
	assert_gt(_health().current, 0.0)
	assert_false(_player.has_component(C_Death))
	context.end()


func test_real_panel_responses_accept_or_refuse_then_release_both_roles_and_focus() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in VAMPIRE_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = VAMPIRE_PROFILE.dialogue_variants[index]
		for service_role: bool in [false, true]:
			_health().current = 60.0
			var previous_focus: int = InteractionControlFocus.current(_player)
			var previous_mouse: Input.MouseMode = Input.mouse_mode
			var visit: CustomerVisit = null
			var agent: C_CustomerAgent = null
			if service_role:
				visit = _delivery_case(person, "vampire/response/%d" % index)
				visit.riddle_solved = true
				NpcServiceRole.begin(body, person, visit, 1)
				agent = body.get_component(C_CustomerAgent) as C_CustomerAgent
				agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
				assert_true(DialoguePanelRouter.open_customer(_player, body, agent))
			else:
				assert_true(DialoguePanelRouter.open_street(_player, body))
			var panel: CustomerDialoguePanel = await _ready_panel()
			var context: NpcDialogueContext = panel.get("_context") as NpcDialogueContext
			panel.call("_advance", "blood_offer")
			await _wait_panel(panel)
			var offer: DialogueLine = panel.get("_line") as DialogueLine
			assert_eq(offer.responses.size(), 3)
			var record: BloodConsentRecord = person.blood_offers.back()
			panel.call("_on_response_pressed", offer.responses[1 if service_role else 0])
			await _wait_panel(panel)
			assert_eq(context.blood_offer_accepted(), not service_role)
			assert_eq(context.blood_offer_declined(), service_role)
			var expected: float = (60.0 if service_role else 60.0 * (1.0 - record.percent / 100.0))
			assert_almost_eq(_health().current, expected, 0.0001)
			assert_true(is_instance_valid(panel))
			assert_eq(
				InteractionControlFocus.current(_player),
				InteractionControlFocus.Priority.MODAL,
			)
			panel.close_dialogue()
			panel.close_dialogue()
			panel.free()
			await get_tree().process_frame
			assert_eq(InteractionControlFocus.current(_player), previous_focus)
			assert_eq(Input.mouse_mode, previous_mouse)
			assert_null(NpcDialogueService.participant(body))
			if service_role:
				assert_false(visit.finished)
				assert_eq(agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
				NpcServiceRole.release(body, visit.visit_id)
			_due_next(person)
#endregion


#region Registered service and private delivery authority
func test_unregistered_variants_require_scan_and_registered_denial_commits_once() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in VAMPIRE_PROFILE.dialogue_variants.size():
		var resource: DialogueResource = _resource(VAMPIRE_PROFILE.dialogue_variants[index])
		var memories_before: int = person.memories.size()
		var visit: CustomerVisit = _case(person, "vampire/unregistered/%d" % index)
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
		visit = _delivery_case(person, "vampire/denial/%d" % index)
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


func test_vampire_variants_preserve_private_home_delivery_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		# This scenario is a resident variant; production Vampire is an authored visitor.
		person.profile = VAMPIRE_PROFILE.duplicate(false) as DEF_NpcArchetype
		person.profile.resident = true
		person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
		person.variation.dialogue_path = VAMPIRE_PROFILE.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "vampire/delivery/%d" % index)
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
func test_vampire_panels_release_focus_and_preserve_visit_in_both_roles() -> void:
	_district.definition.personal_delivery_probability = 0.0
	var person: NpcRecord = _vampire_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in VAMPIRE_PROFILE.dialogue_variants.size():
		person.variation.dialogue_path = VAMPIRE_PROFILE.dialogue_variants[index]
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
		var visit: CustomerVisit = _delivery_case(person, "vampire/panel/%d" % index)
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
