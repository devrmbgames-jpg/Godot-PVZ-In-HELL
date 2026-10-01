extends GutTest

var _world: World = null
var _actor: Entity = null
var _customer: E_Customer = null
var _visit: CustomerVisit = null
var _context: CustomerDialogueContext = null


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world

	var owner: Entity = Entity.new()
	var flow: C_CustomerFlow = C_CustomerFlow.new()
	var cycle: C_DayCycle = C_DayCycle.new()
	cycle.phase = C_DayCycle.Phase.DAY
	cycle.day_index = 3
	owner.component_resources = [flow, cycle, C_Wallet.new(), C_PackageLedger.new()]
	_world.add_entity(owner)

	_visit = CustomerVisit.new()
	_visit.visit_id = &"visit/dialogue"
	_visit.package_id = "dialogue-package"
	_visit.customer_id = &"dialogue-customer"
	_visit.definition = DEF_Customer.new()
	_visit.started = true
	flow.visits.append(_visit)

	_actor = Entity.new()
	_world.add_entity(_actor)

	_customer = E_Customer.new()
	var agent: C_CustomerAgent = C_CustomerAgent.new()
	agent.visit_id = _visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	_customer.component_resources = [agent]
	_world.add_entity(_customer)

	_context = CustomerDialogueContext.new(_actor, _customer)


func after_each() -> void:
	if is_instance_valid(_world):
		_world.free()
	_world = null
	_actor = null
	_customer = null
	_visit = null
	_context = null
	ECS.world = null


func _ready_check() -> PackageDeliveryCheck:
	var result: PackageDeliveryCheck = PackageDeliveryCheck.new()
	result.result = PackageDeliveryCheck.Result.READY
	return result


func _add_requested_package() -> C_PackageState:
	var parcel: Entity = Entity.new()
	var identity: C_Package = C_Package.new()
	identity.package_id = _visit.package_id
	var state: C_PackageState = C_PackageState.new()
	state.registration = C_PackageState.Registration.REGISTERED
	parcel.component_resources = [identity, state]
	_world.add_entity(parcel)
	return parcel.get_component(C_PackageState) as C_PackageState


func _reaction(
	intent: CustomerDialogueIntent.Type,
	satisfaction_delta: int,
	complaint_delta: float,
	aggression_delta: float,
	followup_delta: float,
) -> DEF_CustomerDialogueReaction:
	var reaction: DEF_CustomerDialogueReaction = DEF_CustomerDialogueReaction.new()
	reaction.intent = intent
	reaction.satisfaction_delta = satisfaction_delta
	reaction.complaint_probability_delta = complaint_delta
	reaction.aggression_probability_delta = aggression_delta
	reaction.followup_probability_delta = followup_delta
	return reaction


func test_response_intent_tags_are_typed_and_idempotent() -> void:
	_visit.definition.dialogue_reactions = [
		_reaction(CustomerDialogueIntent.Type.LIE, -20, 0.25, 0.1, 0.05),
	]
	assert_true(_context.apply_response_tags(PackedStringArray(["lie"])))
	assert_eq(_visit.last_dialogue_intent, CustomerDialogueIntent.Type.LIE)
	assert_eq(_visit.dialogue_satisfaction_delta, -20)
	assert_almost_eq(_visit.complaint_probability_delta, 0.25, 0.001)
	assert_true(_context.apply_response_tags(PackedStringArray(["lie"])))
	assert_eq(_visit.dialogue_satisfaction_delta, -20)


func test_joke_tag_does_not_commit_denial() -> void:
	_visit.definition.dialogue_reactions = [
		_reaction(CustomerDialogueIntent.Type.JOKE, -5, 0.0, 0.0, 0.0),
	]
	assert_true(_context.apply_response_tags(PackedStringArray(["jok"])))
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_visit.dialogue_satisfaction_delta, -5)


func test_threat_reaction_can_escalate_dialogue_denial_to_aggressive() -> void:
	_visit.definition.immediate_aggression_probability = 0.0
	_visit.definition.dialogue_reactions = [
		_reaction(CustomerDialogueIntent.Type.THREAT, -40, 0.2, 1.0, -0.2),
	]
	_visit.aggression_roll = 0.5
	assert_true(_context.apply_response_tags(PackedStringArray(["thr"])))
	assert_true(_context.commit_denial())
	assert_eq(_visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(_visit.player_denial_count, 1)
	assert_true(_visit.aggressive)
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(agent.phase, C_CustomerAgent.Phase.AGGRESSIVE)


func test_persuasion_modifier_reduces_complaint_and_increases_followup() -> void:
	_visit.definition.complaint_probability = 0.85
	_visit.definition.followup_probability = 0.5
	_visit.definition.dialogue_reactions = [
		_reaction(CustomerDialogueIntent.Type.PERSUADE, -5, -0.55, 0.0, 0.25),
	]
	assert_true(_context.apply_response_tags(PackedStringArray(["prs"])))
	assert_almost_eq(_visit.complaint_probability_delta, -0.55, 0.001)
	assert_almost_eq(_visit.followup_probability_delta, 0.25, 0.001)


func test_riddle_wrong_answer_is_idempotent_and_affects_final_satisfaction() -> void:
	_visit.definition.dialogue_mode = DEF_Customer.DialogueMode.RIDDLE
	_visit.definition.riddle_wrong_satisfaction_penalty = 20
	assert_eq(_context.dialogue_cue(), "riddle")
	assert_true(_context.begin())
	assert_true(_context.answer_riddle_wrong())
	assert_true(_context.answer_riddle_wrong())
	assert_eq(_visit.dialogue_satisfaction_delta, -20)
	assert_eq(_context.satisfaction(), 80)
	assert_true(CustomerOutcomeService.receive(_visit, _ready_check()))
	assert_eq(_visit.satisfaction, 80)
	assert_true(_context.answer_riddle_correct())
	assert_eq(_context.dialogue_cue(), "direct")


func test_condition_adapter_reads_package_and_complaint_facts() -> void:
	var state: C_PackageState = _add_requested_package()
	state.opening = C_PackageState.Opening.OPENED
	state.damage = C_PackageState.Damage.DAMAGED
	assert_true(_context.package_opened())
	assert_true(_context.package_damaged())
	assert_eq(_context.package_actual_outcome(), CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_context.terminal_declaration(), CustomerVisit.Declaration.NONE)
	assert_false(_context.has_complaint())
	assert_eq(_context.complaint_outcome(), CustomerDialogueContext.NO_COMPLAINT)
	assert_eq(_context.challenge_result(), CustomerDialogueContext.NO_CHALLENGE_RESULT)
	assert_eq(_context.hunger_tier(), CustomerDialogueContext.DEFAULT_HUNGER_TIER)


func test_forced_delayed_complaint_is_idempotent() -> void:
	assert_true(_context.schedule_non_delivery_complaint())
	var first: CustomerComplaint = _visit.complaint
	assert_not_null(first)
	assert_eq(first.created_day, 3)
	assert_eq(first.resolve_day, 4)
	assert_true(_context.schedule_non_delivery_complaint())
	assert_same(_visit.complaint, first)
	assert_true(_context.complaint_pending())


func test_false_taken_detection_routes_to_existing_aggressive_receiver() -> void:
	_visit.aggression_roll = 0.0
	_visit.definition.immediate_aggression_probability = 1.0
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	var waiting_agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(waiting_agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	assert_true(_context.false_taken_detected())
	assert_eq(_context.dialogue_cue(), "false_taken")
	assert_true(_context.begin())
	assert_true(_context.schedule_non_delivery_complaint())
	assert_true(_context.enter_aggressive())
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(agent.phase, C_CustomerAgent.Phase.AGGRESSIVE)
	assert_false(agent.moving)


func test_voluntary_refusal_uses_customer_flow_transition() -> void:
	_visit.definition.voluntary_refusal = true
	assert_eq(_context.dialogue_cue(), "voluntary_refusal")
	assert_true(_context.begin())
	assert_true(_context.voluntary_refuse())
	assert_eq(_visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_eq(agent.phase, C_CustomerAgent.Phase.LEAVING)
	assert_false(_context.voluntary_refuse())


func test_context_invalidates_when_customer_dies_or_visit_finishes() -> void:
	assert_true(_context.is_valid())
	_customer.add_component(C_Death.new())
	assert_false(_context.is_valid())
	_customer.remove_component(C_Death)
	_visit.finished = true
	assert_false(_context.is_valid())


func test_response_prefixes_preserve_authored_text_and_routing_tags() -> void:
	var cases: Dictionary[String, String] = {
		"hon": "[честно]", "lie": "[обман]", "prs": "[убедить]",
		"thr": "[угроза]", "flr": "[флирт]", "jok": "[шутка]",
	}
	for tag: String in cases:
		var response: DialogueResponse = DialogueResponse.new()
		response.text = "Посылки ещё не было"
		response.tags = PackedStringArray([tag])
		var intent: CustomerDialogueIntent.Type = CustomerDialogueIntent.from_tags(response.tags)
		var displayed: String = CustomerDialoguePanel.format_response_text(response.text, response.tags)
		assert_eq(displayed, cases[tag] + " " + response.text)
		assert_eq(CustomerDialoguePanel.format_response_text(displayed, response.tags), displayed)
		assert_eq(response.text, "Посылки ещё не было")
		assert_eq(response.tags, PackedStringArray([tag]))
		assert_eq(CustomerDialogueIntent.from_tags(response.tags), intent)
	assert_eq(CustomerDialoguePanel.format_response_text("Хорошо.", PackedStringArray()), "Хорошо.")
	assert_eq(CustomerDialoguePanel.format_response_text("Хорошо.", PackedStringArray(["unknown"])), "Хорошо.")


func test_dialogue_resource_exposes_direct_and_riddle_branches() -> void:
	var resource: DialogueResource = load(CustomerDialogueService.DIALOGUE_PATH) as DialogueResource
	assert_not_null(resource)
	var direct: DialogueLine = await resource.get_next_dialogue_line("direct", [{"ctx": _context}])
	assert_not_null(direct)
	assert_eq(direct.character, "Клиент")
	var deny_start: DialogueLine = await resource.get_next_dialogue_line("deny_start", [{"ctx": _context}])
	assert_not_null(deny_start)
	assert_eq(deny_start.responses.size(), 6)
	assert_true((deny_start.responses[1] as DialogueResponse).has_tag("lie"))
	assert_true((deny_start.responses[4] as DialogueResponse).has_tag("thr"))
	assert_true((deny_start.responses[5] as DialogueResponse).has_tag("jok"))
	var persuade: DialogueLine = await resource.get_next_dialogue_line("deny_persuade", [{"ctx": _context}])
	assert_not_null(persuade)
	_visit.visit_count = 2
	assert_eq(_context.dialogue_cue(), "followup")
	_visit.visit_count = 1
	_visit.definition.dialogue_mode = DEF_Customer.DialogueMode.RIDDLE
	var riddle: DialogueLine = await resource.get_next_dialogue_line("riddle", [{"ctx": _context}])
	assert_not_null(riddle)
	assert_eq(riddle.responses.size(), 3)
