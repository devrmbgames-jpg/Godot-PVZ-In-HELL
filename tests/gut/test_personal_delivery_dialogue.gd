extends "res://tests/gut/test_district_delivery.gd"
## Проверяет реальные личные диалоги, сохранённый торг и авторскую засаду в LimboAI.

class ObservedCustomerContext extends CustomerDialogueContext:
	## Свидетельство порядка закрытия настоящей панели перед привязкой противника.
	var closed_before_combat: bool = false
	## Панель уже освободила модальный ввод при завершении контекста.
	var released_before_end: bool = false

	#region Наблюдение жизненного цикла
	## Сохраняет наблюдения, затем выполняет обычное завершение обслуживания.
	func end() -> void:
		closed_before_combat = CombatService.target_for(_delivery_npc()) == null
		released_before_end = InteractionControlFocus.current(_delivery_player()) < InteractionControlFocus.Priority.MODAL
		super.end()
	#endregion

var _resources: Array[DialogueResource] = []
var _panels: Array[CustomerDialoguePanel] = []

#region Минимальное окружение диалога
## Закрывает панели и ссылки Dialogue Manager до удаления физического World.
func after_each() -> void:
	for panel: CustomerDialoguePanel in _panels:
		if is_instance_valid(panel):
			panel.close_dialogue()
			panel.free()
	for resource: DialogueResource in _resources:
		DialogueResourceLifecycle.release_runtime_references(resource)
	_panels.clear()
	_resources.clear()
	super.after_each()

func _stage(person: NpcRecord) -> E_DistrictNpc:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	body.place_at(NpcPopulationQueries.position_for(person.home_id))
	(_player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	return body

func _customer_context(body: E_DistrictNpc, visit: CustomerVisit) -> CustomerDialogueContext:
	visit.riddle_solved = true
	if not body.has_component(C_CustomerAgent):
		NpcServiceRole.begin(body, NpcPopulationQueries.person_for(visit.customer_id), visit, 1)
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: CustomerDialogueContext = CustomerDialogueContext.new(_player, body)
	assert_true(context.begin())
	return context

func _resource(path: String) -> DialogueResource:
	var resource: DialogueResource = load(path) as DialogueResource
	_resources.append(resource)
	return resource

func _prompt(resource: DialogueResource, context: NpcDialogueContext, cue: String) -> DialogueLine:
	var line: DialogueLine = await resource.get_next_dialogue_line(cue, [{"ctx": context}])
	for step: int in range(5):
		if line == null or not line.responses.is_empty():
			return line
		line = await resource.get_next_dialogue_line(line.next_id, [{"ctx": context}])
	fail_test("Диалог не дошёл до выбора за пять реплик")
	return line

func _allowed(line: DialogueLine) -> Array[DialogueResponse]:
	var result: Array[DialogueResponse] = []
	for response: DialogueResponse in line.responses:
		if response.is_allowed:
			result.append(response)
	return result

func _copy_job(job: NpcHomeDelivery) -> NpcHomeDelivery:
	var copy: NpcHomeDelivery = NpcHomeDelivery.new()
	var fields: Dictionary = (SaveDataCodec.encode(job) as Dictionary).fields as Dictionary
	assert_true(SaveDataCodec.apply_fields(copy, fields))
	return copy

func _published(visit: CustomerVisit) -> TerminalDeliveryInfo:
	var visits: Dictionary[String, CustomerVisit] = {visit.package_id: visit}
	return HomeDeliveryQueries.published_by_package(PackageQueries.ledger(), PackageQueries.live_states(), visits).get(visit.package_id) as TerminalDeliveryInfo

func _panel(context: NpcDialogueContext, resource: DialogueResource, cue: String) -> CustomerDialoguePanel:
	var panel: CustomerDialoguePanel = CustomerDialoguePanel.new()
	_root.add_child(panel)
	_panels.append(panel)
	assert_true(panel.open_for(_player, context, resource, cue))
	return panel

func _trap() -> NpcHomeDelivery:
	_district.definition.force_personal_delivery_scenario = true
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "trap")
	var job: NpcHomeDelivery = _district.home_deliveries[0]
	assert_eq(job.scenario_id, _district.definition.personal_delivery_scenario.key)
	assert_true(NpcDeliveryOfferService.accept(job.job_id))
	_stage(person)
	assert_true(NpcHomeDeliveryService.knock(_player, _door(person.home_id)))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	return job
#endregion

#region Реальный выбор, торг и приватность
## Клиент видит адрес и цену; один успешный торг переживает повторный разговор и сериализацию.
func test_customer_bargain_is_once_and_acceptance_stays_private() -> void:
	_district.definition.delivery_bargain_probability = 1.0
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "customer_bargain")
	var body: E_DistrictNpc = _stage(person)
	var context: CustomerDialogueContext = _customer_context(body, visit)
	var resource: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	var offer: DialogueLine = await resource.get_next_dialogue_line(context.dialogue_cue(), [{"ctx": context}])
	assert_string_contains(offer.text, context.delivery_address())
	assert_string_contains(offer.text, "10$")
	var prompt: DialogueLine = await _prompt(resource, context, offer.next_id)
	assert_eq(_allowed(prompt).size(), 3)
	var bargain: DialogueResponse = _allowed(prompt)[1]
	assert_string_contains(bargain.text, "15$")
	prompt = await _prompt(resource, context, bargain.next_id)
	assert_eq(_allowed(prompt).size(), 2)
	assert_eq(context.delivery_bonus(), 15)
	assert_true(context.delivery_bargain_accepted())
	assert_false(context.can_bargain_delivery())

	var job: NpcHomeDelivery = _district.home_deliveries[0]
	var saved: NpcHomeDelivery = _copy_job(job)
	_district.home_deliveries[0] = saved
	context.end()
	context = _customer_context(body, visit)
	_district.definition.delivery_bargain_probability = 0.0
	assert_true(context.negotiate_home_delivery())
	assert_eq(saved.bargain, NpcHomeDelivery.Bargain.ACCEPTED)
	assert_eq(saved.bonus, 15)
	assert_eq(saved.bargain_roll, job.bargain_roll)
	prompt = await _prompt(resource, context, "home_request")
	var end_line: DialogueLine = await resource.get_next_dialogue_line(_allowed(prompt)[0].next_id, [{"ctx": context}])
	assert_null(end_line)
	assert_eq(saved.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_false(saved.published)
	assert_null(_published(visit))
	assert_not_null(PackageQueries.find_live_package(visit.package_id))
	assert_eq(WalletService.current().operations.size(), 0)
	context.end()

## Уличный отказ в повышении цены не перебрасывается; отказ игрока сохраняет обычный заказ и коробку.
func test_street_declined_bargain_and_delivery_keep_order() -> void:
	_district.definition.delivery_bargain_probability = 0.0
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "street_bargain")
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	var resource: DialogueResource = _resource(NpcDialogueService.DIALOGUE_PATH)
	var prompt: DialogueLine = await _prompt(resource, context, context.dialogue_cue())
	assert_eq(_allowed(prompt).size(), 3)
	prompt = await _prompt(resource, context, _allowed(prompt)[1].next_id)
	assert_eq(context.delivery_bonus(), 10)
	assert_false(context.delivery_bargain_accepted())
	assert_eq(_allowed(prompt).size(), 2)
	_district.definition.delivery_bargain_probability = 1.0
	assert_true(context.negotiate_home_delivery())
	assert_eq(context.delivery_bonus(), 10)
	var end_line: DialogueLine = await resource.get_next_dialogue_line(_allowed(prompt)[1].next_id, [{"ctx": context}])
	assert_null(end_line)
	assert_eq(_district.home_deliveries[0].status, NpcHomeDelivery.Status.DECLINED)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_not_null(PackageQueries.find_live_package(visit.package_id))
	assert_null(visit.complaint)
	assert_eq(WalletService.current().operations.size(), 0)
	context.end()

## Обычный минимум не назначает ловушку; явный сюжетный override сохраняет ID и публикует только подсказку.
func test_scenario_override_is_stable_and_not_published() -> void:
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "override")
	assert_true(_district.home_deliveries[0].scenario_id.is_empty())
	var scenario: DEF_NpcDeliveryScenario = _district.definition.personal_delivery_scenario
	var job: NpcHomeDelivery = NpcDeliveryOfferService.assign_personal(visit.visit_id, scenario.key)
	assert_same(NpcDeliveryOfferService.assign_personal(visit.visit_id, scenario.key), job)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, _stage(person))
	assert_true(context.begin())
	assert_eq(context.delivery_hint(), scenario.offer_hint)
	assert_false(context.delivery_hint().contains(String(scenario.key)))
	assert_null(_published(visit))
	assert_eq(_copy_job(job).scenario_id, scenario.key)
	context.end()
#endregion

#region Память о сорванном обещании
## Агрессор сохраняет будущую реакцию ночью; при следующем разговоре панель закрывается перед боем.
func test_failed_promise_reacts_once_after_dialogue_and_blocks_personal_work() -> void:
	var person: NpcRecord = _district.people[0]
	person.profile = person.profile.duplicate() as DEF_NpcProfile
	person.profile.personality = DEF_NpcProfile.Personality.AGGRESSIVE
	person.profile.high_attack_probability = 1.0
	var visit: CustomerVisit = _delivery_case(person, "broken_promise")
	var job: NpcHomeDelivery = _district.home_deliveries[0]
	var body: E_DistrictNpc = _stage(person)
	assert_true(NpcDeliveryOfferService.accept(job.job_id))
	NpcHomeDeliveryService.finish_evening(1)
	NpcHomeDeliveryService.finish_evening(1)
	assert_eq(person.memories.size(), 1)
	assert_eq(person.memories[0].reaction, NpcMemory.Reaction.ATTACK)
	assert_null(CombatService.target_for(body))
	assert_true(NpcSocialService.distrusts_player(person))
	assert_eq(WalletService.current().operations.size(), 0)
	assert_null(visit.complaint)
	assert_false(CustomerSocialService.resolve_promise(body, _player))

	DayPhaseQueries.current().day_index = 2
	var next: CustomerVisit = _delivery_case(person, "distrust_next")
	assert_null(HomeDeliveryQueries.personal_for(person.npc_id))
	assert_eq(_district.home_deliveries.back().source, NpcHomeDelivery.Source.TERMINAL)
	NpcServiceRole.begin(body, person, next, 2)
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: ObservedCustomerContext = ObservedCustomerContext.new(_player, body)
	assert_true(context.begin())
	assert_eq(context.dialogue_cue(), "broken_promise")
	var resource: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	_panel(context, resource, context.dialogue_cue())
	var prompt: DialogueLine = await _prompt(resource, context, context.dialogue_cue())
	person.profile.high_attack_probability = 0.0
	var end_line: DialogueLine = await resource.get_next_dialogue_line(_allowed(prompt)[0].next_id, [{"ctx": context}])
	assert_null(end_line)
	assert_true(context.closed_before_combat)
	assert_true(context.released_before_end)
	assert_same(CombatService.target_for(body), _player)
	assert_true(job.promise_reaction_applied)
	assert_true(_copy_job(job).promise_reaction_applied)
	assert_false(CustomerSocialService.resolve_promise(body, _player))
	assert_eq(person.memories.size(), 1)

## Трус отвечает бегством на срыв своего обещания; системная доставка не лишает личного доверия.
func test_timid_promise_flees_but_terminal_failure_does_not_remove_personal_trust() -> void:
	var person: NpcRecord = _district.people[0]
	person.profile = person.profile.duplicate() as DEF_NpcProfile
	person.profile.personality = DEF_NpcProfile.Personality.TIMID
	person.profile.timid_flee_probability = 1.0
	_delivery_case(person, "timid_promise")
	var body: E_DistrictNpc = _stage(person)
	assert_true(NpcDeliveryOfferService.accept(_district.home_deliveries[0].job_id))
	var other: NpcRecord = _district.people[3]
	_delivery_case(other, "terminal_failure")
	assert_true(NpcDeliveryOfferService.accept(_district.home_deliveries[1].job_id))
	NpcHomeDeliveryService.finish_evening(1)
	assert_eq(person.memories[0].reaction, NpcMemory.Reaction.FLEE)
	assert_false(NpcSocialService.distrusts_player(other))
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_true(context.resolve_broken_promise())
	assert_true((body.get_component(C_NpcAwareness) as C_NpcAwareness).fleeing)
	assert_null(CombatService.target_for(body))
	assert_null(NpcDialogueService.participant(body))
#endregion

#region Авторская засада и дерево
## Отказ от сценарного предложения не запускает встречу, не закрывает заказ и не создаёт неприязнь.
func test_declining_authored_trap_preserves_normal_collection() -> void:
	_district.definition.force_personal_delivery_scenario = true
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "declined_trap")
	var body: E_DistrictNpc = _stage(person)
	var context: NpcStreetDialogueContext = NpcStreetDialogueContext.new(_player, body)
	assert_true(context.begin())
	assert_false(context.delivery_hint().is_empty())
	assert_true(context.decline_home_delivery())
	context.end()
	assert_false(NpcHomeDeliveryService.knock(_player, _door(person.home_id)))
	assert_null(NpcDeliveryScenarioService.armed_for(body))
	assert_null(CombatService.target_for(body))
	assert_not_null(PackageQueries.find_live_package(visit.package_id))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	NpcHomeDeliveryService.finish_evening(1)
	assert_true(person.memories.is_empty())
	assert_eq(WalletService.current().operations.size(), 0)
	assert_eq(CustomerFlowFixture.reactivate(CustomerFlowQueries.current(), visit.next_followup_day), 1)
	assert_false(visit.finished)

## Дерево ждёт невидимого/далёкого игрока; повторный стук и прямой приём не обходят сценарий.
func test_trap_waits_for_visible_near_player_without_receiving_box() -> void:
	var job: NpcHomeDelivery = _trap()
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	var parcel: Entity = PackageQueries.find_live_package(job.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.UNASSIGNED)
	assert_true(NpcHomeDeliveryService.knock(_player, _door(job.address_id)))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.player_visible = false
	assert_true(_run_tree(body, "res://content/domains/customers/ai/trees/bt_npc_service.tres", 0.2))
	assert_null(CombatService.target_for(body))
	awareness.player_visible = true
	(_player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD * 8.0
	assert_true(_run_tree(body, "res://content/domains/customers/ai/trees/bt_npc_service.tres", 0.2))
	assert_null(CombatService.target_for(body))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_same(PackageQueries.find_live_package(job.package_id), parcel)
	assert_eq(WalletService.current().operations.size(), 0)

## Настоящее поддерево освобождает панель/связи до боя и не повторяет засаду или выплаты после загрузки.
func test_native_trap_closes_conversation_before_combat_and_does_not_repeat() -> void:
	var job: NpcHomeDelivery = _trap()
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	(body.get_component(C_CustomerAgent) as C_CustomerAgent).phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var context: ObservedCustomerContext = ObservedCustomerContext.new(_player, body)
	assert_true(context.begin())
	var resource: DialogueResource = _resource(CustomerDialogueService.DIALOGUE_PATH)
	_panel(context, resource, "direct")
	assert_eq(InteractionControlFocus.current(_player), InteractionControlFocus.Priority.MODAL)
	var health: C_Health = body.get_component(C_Health) as C_Health
	var original_health: float = health.current
	(body.get_component(C_NpcAwareness) as C_NpcAwareness).player_visible = true
	assert_false(NpcDeliveryScenarioService.start_ambush(body))
	assert_true(_run_tree(body, "res://content/domains/customers/ai/trees/bt_npc_service.tres", 0.2))
	assert_true(context.closed_before_combat)
	assert_true(context.released_before_end)
	assert_same(CombatService.target_for(body), _player)
	assert_eq((body.get_component(C_NpcDecision) as C_NpcDecision).intent_owner, C_NpcDecision.Owner.COMBAT)
	assert_null(NpcDialogueService.participant(body))
	assert_null(HomeMeetingQueries.meeting_for(body))
	assert_false(body.has_component(C_CustomerAgent))
	assert_eq(job.status, NpcHomeDelivery.Status.AMBUSHED)
	assert_eq(health.current, original_health)
	assert_not_null(PackageQueries.find_live_package(job.package_id))
	_district.home_deliveries[0] = _copy_job(job)
	assert_false(NpcDeliveryScenarioService.start_ambush(body))
	NpcHomeDeliveryService.finish_evening(1)
	assert_eq(_district.home_deliveries[0].status, NpcHomeDelivery.Status.AMBUSHED)
	assert_eq(NpcPopulationQueries.person_for(job.npc_id).memories.size(), 0)
	assert_eq(WalletService.current().operations.size(), 0)

## До прибытия к дому ловушка не блокирует обычное движение к назначенной двери.
func test_trap_uses_normal_approach_before_home() -> void:
	var job: NpcHomeDelivery = _trap()
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	body.place_at(NpcPopulationQueries.position_for(job.address_id) + Vector3.RIGHT * 6.0)
	(body.get_component(C_NpcAwareness) as C_NpcAwareness).player_visible = true
	assert_true(_run_tree(body, "res://content/domains/customers/ai/trees/bt_npc_service.tres", 0.2))
	assert_null(CombatService.target_for(body))
	assert_true((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert_not_null(HomeMeetingQueries.meeting_for(body))
#endregion
