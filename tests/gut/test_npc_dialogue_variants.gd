extends "res://tests/gut/test_district_delivery.gd"
## Exercises imported personal variants, stable restoration and real street/customer routing.

const LOST_PATH: String = "res://content/domains/npc/definitions/def_npc_archetype_lost.tres"

var _dialogue_resources: Array[DialogueResource] = []


#region Native dialogue fixture
func after_each() -> void:
	for candidate: Node in get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP):
		var panel: CustomerDialoguePanel = candidate as CustomerDialoguePanel
		if panel != null:
			panel.close_dialogue()
			panel.free()
	for resource: DialogueResource in _dialogue_resources:
		DialogueResourceLifecycle.release_runtime_references(resource)
	_dialogue_resources.clear()
	super.after_each()


func _lost_person() -> NpcRecord:
	var person: NpcRecord = _district.people[0]
	person.profile = load(LOST_PATH) as DEF_NpcArchetype
	person.variation = NpcVariationRules.create(person.profile, 1234, person.npc_id, 1)
	return person


func _stage(person: NpcRecord) -> E_DistrictNpc:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.place_at(NpcPopulationQueries.position_for(person.home_id))
	(_player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	return body


func _resource(path: String) -> DialogueResource:
	var resource: DialogueResource = load(path) as DialogueResource
	_dialogue_resources.append(resource)
	return resource


func _line(resource: DialogueResource, context: NpcDialogueContext, cue: String) -> DialogueLine:
	return await resource.get_next_dialogue_line(cue, [{ "ctx": context }])


func _service_context(body: E_DistrictNpc, visit: CustomerVisit) -> CustomerDialogueContext:
	visit.riddle_solved = true
	NpcServiceRole.begin(body, NpcPopulationQueries.person_for(visit.customer_id), visit, 1)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: CustomerDialogueContext = CustomerDialogueContext.new(_player, body)
	assert_true(context.begin())
	return context
#endregion


#region Imported content and committed selection
func test_imported_variants_preserve_every_role_entry_cue() -> void:
	var archetype: DEF_NpcArchetype = load(LOST_PATH) as DEF_NpcArchetype
	assert_eq(archetype.dialogue_variants.size(), 2)
	assert_true(archetype.valid_rules())
	var street: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var service: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	for path: String in archetype.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		assert_not_null(resource)
		assert_eq(resource.get_meta("dialogue_manager_version"), "4.1.0")
		for cue: String in street.cues:
			assert_true(resource.cues.has(cue), path + ": " + cue)
		for cue: String in service.cues:
			assert_true(resource.cues.has(cue), path + ": " + cue)


func test_opening_and_codec_restore_read_the_same_committed_variant() -> void:
	var person: NpcRecord = _lost_person()
	var body: E_DistrictNpc = _stage(person)
	var selected: String = person.variation.dialogue_path
	var saved: Dictionary = SaveDataCodec.encode(person) as Dictionary
	var restored: NpcRecord = NpcRecord.new()
	assert_true(SaveDataCodec.apply_fields(restored, saved.fields as Dictionary))
	_district.people[0] = restored
	for repeat: int in range(4):
		assert_eq(NpcDialogueService.dialogue_path_for(body), selected)
		assert_eq(
			NpcDialogueService.dialogue_path_for(body, CustomerDialogueService.DIALOGUE_PATH),
			selected,
		)
	assert_eq(SaveDataCodec.encode(restored), saved)
	var definition: DEF_NpcArchetype = restored.profile.duplicate() as DEF_NpcArchetype
	definition.dialogue_variants.reverse()
	restored.profile = definition
	assert_eq(NpcDialogueService.dialogue_path_for(body), selected)


func test_legacy_actor_and_empty_committed_path_keep_role_fallback() -> void:
	var actor: Entity = Entity.new()
	_world.add_entity(actor)
	assert_eq(NpcDialogueService.dialogue_path_for(actor), NpcDialogueService.DIALOGUE_PATH)
	assert_eq(
		NpcDialogueService.dialogue_path_for(actor, CustomerDialogueService.DIALOGUE_PATH),
		CustomerDialogueService.DIALOGUE_PATH,
	)
	var person: NpcRecord = _district.people[0]
	assert_eq(person.variation.dialogue_path, "")
	assert_eq(
		NpcDialogueService.dialogue_path_for(_stage(person), CustomerDialogueService.DIALOGUE_PATH),
		CustomerDialogueService.DIALOGUE_PATH,
	)
#endregion


#region Real context flows and panel routing
func test_both_variants_keep_real_street_and_customer_delivery_acceptance() -> void:
	var archetype: DEF_NpcArchetype = load(LOST_PATH) as DEF_NpcArchetype
	_district.definition.personal_delivery_probability = 1.0
	for index: int in range(4):
		var person: NpcRecord = _district.people[index]
		person.profile = archetype
		person.variation = NpcVariationRules.create(archetype, 1234, person.npc_id, 1)
		person.variation.dialogue_path = archetype.dialogue_variants[index / 2]
		var visit: CustomerVisit = _delivery_case(person, "variant_delivery_%d" % index)
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


func test_closing_variant_releases_imported_line_cycles() -> void:
	var person: NpcRecord = _lost_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var imported: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var resource: DialogueResource = _resource(person.variation.dialogue_path)
	assert_not_null(await _line(resource, context, "street"))
	assert_not_null(await _line(resource, context, "joke"))
	var retained: int = 0
	for value: Variant in imported.lines.values():
		if (value as Dictionary).get("resource") == imported:
			retained += 1
	assert_gt(retained, 0, "The native imported branch retains its own resource")
	DialogueResourceLifecycle.release_runtime_references(resource)
	DialogueResourceLifecycle.release_runtime_references(resource)
	for affected: DialogueResource in [resource, imported]:
		for value: Variant in affected.lines.values():
			assert_false((value as Dictionary).has("resource"))
	context.end()


func test_both_street_variants_offer_distinct_topics_and_tagged_responses() -> void:
	var person: NpcRecord = _lost_person()
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var greetings: Array[String] = []
	for path: String in person.profile.dialogue_variants:
		var resource: DialogueResource = _resource(path)
		var greeting: DialogueLine = await _line(resource, context, "street")
		assert_eq(greeting.character, person.display_name)
		greetings.append(greeting.text)
		var neighborhood: DialogueLine = await _line(resource, context, "neighborhood")
		var response: DialogueResponse = neighborhood.responses[2] as DialogueResponse
		assert_true(response.has_tag("lie"))
		assert_string_contains(
			CustomerDialoguePanel.format_response_text(response.text, response.tags),
			"[обман]",
		)
		var goods: DialogueLine = await _line(resource, context, "goods")
		assert_eq(goods.responses.size(), 4)
		for index: int in range(3):
			var topic: DialogueLine = await _line(
				resource,
				context,
				(goods.responses[index] as DialogueResponse).next_id,
			)
			assert_not_null(topic)
			assert_null(await _line(resource, context, topic.next_id))
	assert_ne(greetings[0], greetings[1])
	context.end()


func test_imported_customer_denial_keeps_tags_and_commits_once() -> void:
	var person: NpcRecord = _lost_person()
	var body: E_DistrictNpc = _stage(person)
	for index: int in person.profile.dialogue_variants.size():
		var visit: CustomerVisit = _case(person, "variant_denial_%d" % index)
		visit.definition = DEF_Customer.new()
		var context: CustomerDialogueContext = _service_context(body, visit)
		var resource: DialogueResource = _resource(person.profile.dialogue_variants[index])
		var direct: DialogueLine = await _line(resource, context, "direct")
		assert_string_contains(direct.text, context.package_number_text())
		var denial: DialogueLine = await _line(resource, context, "deny_start")
		assert_eq(denial.responses.size(), 6)
		var lie: DialogueResponse = denial.responses[1] as DialogueResponse
		assert_true(lie.has_tag("lie"))
		assert_true((denial.responses[2] as DialogueResponse).has_tag("prs"))
		var refusal: DialogueLine = await _line(resource, context, lie.next_id)
		assert_not_null(refusal)
		assert_null(await _line(resource, context, refusal.next_id))
		assert_eq(visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
		assert_eq(visit.player_denial_count, 1)
		assert_false(context.commit_denial())
		assert_eq(visit.player_denial_count, 1)
		context.end()
		NpcServiceRole.release(body, visit.visit_id)


func test_router_uses_personal_street_variant_and_explicit_customer_override() -> void:
	var person: NpcRecord = _lost_person()
	var body: E_DistrictNpc = _stage(person)
	assert_true(DialoguePanelRouter.open_street(_player, body))
	var panels: Array[Node] = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
	assert_eq(panels.size(), 1)
	var panel: CustomerDialoguePanel = panels[0] as CustomerDialoguePanel
	var selected: DialogueResource = panel.get("_resource") as DialogueResource
	assert_eq(selected.resource_path, person.variation.dialogue_path)
	panel.close_dialogue()
	panel.free()
	await get_tree().process_frame
	for explicit_path: String in ["", CustomerDialogueService.DIALOGUE_PATH]:
		var visit: CustomerVisit = _case(person, "routing_" + explicit_path)
		visit.definition = DEF_Customer.new()
		visit.definition.dialogue_resource_path = explicit_path
		visit.riddle_solved = true
		NpcServiceRole.begin(body, person, visit, 1)
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		assert_true(DialoguePanelRouter.open_customer(_player, body, agent))
		panels = get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP)
		assert_eq(panels.size(), 1)
		panel = panels[0] as CustomerDialoguePanel
		selected = panel.get("_resource") as DialogueResource
		assert_eq(
			selected.resource_path,
			person.variation.dialogue_path if explicit_path.is_empty() else explicit_path,
		)
		panel.close_dialogue()
		panel.free()
		NpcServiceRole.release(body, visit.visit_id)
		await get_tree().process_frame
#endregion
