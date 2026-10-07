extends GutTest
## Проверяет задание отказа по постоянной коробке и фактическому исходу обслуживания.

var _world: World = null
var _cycle: C_DayCycle = null
var _wallet: C_Wallet = null
var _state: C_QuestSession = null
var _flow: C_CustomerFlow = null
var _trader: Entity = null
var _parcel: Entity = null
var _visit: CustomerVisit = null


#region Окружение задания
## Создаёт торговца, постоянную коробку и заказ с реальной регистрацией.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_RefusalQuest.new())
	var session: Entity = Entity.new()
	session.component_resources = [
		C_DayCycle.new(), C_Wallet.new(), C_QuestSession.new(), C_PackageLedger.new(),
		C_CustomerFlow.new(), C_BoundaryTrace.new()
	]
	_world.add_entity(session)
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_wallet = session.get_component(C_Wallet) as C_Wallet
	_state = session.get_component(C_QuestSession) as C_QuestSession
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle.phase = C_DayCycle.Phase.EVENING
	_wallet.balance = 500
	_trader = Entity.new()
	_trader.component_resources = [C_Trader.new()]
	_world.add_entity(_trader)
	_parcel = Entity.new()

	var identity: C_Package = C_Package.new()
	identity.package_id = "durable:first"
	_parcel.component_resources = [identity]
	_world.add_entity(_parcel)
	var registration: PackageRegistrationRecord = PackageRegistrationRecord.new()
	registration.package_id = identity.package_id
	registration.number = 3
	PackageRegistrationService.ledger().records.append(registration)
	_visit = CustomerVisit.new()
	_visit.visit_id = &"visit/durable:first"
	_visit.package_id = identity.package_id
	_visit.customer_id = &"recipient:first"
	_visit.definition = DEF_Customer.new()
	_visit.arrival_day = 2
	_visit.accounting_value = 100
	_flow.visits.append(_visit)


## Удаляет World и сбрасывает глобальную ссылку ECS.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


#endregion

#region Постоянная цель и фактический исход
## Diagnostic completion agrees with the single committed quest/reward ledger.
func test_quest_trace_reports_choice_rejection_and_exactly_one_reward() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.accept(record.quest_id))
	assert_false(RefusalQuestService.accept(record.quest_id))
	var trace_rows: Array[Dictionary] = BoundaryTrace.snapshots(String(record.quest_id))
	assert_eq(trace_rows.size(), 3)
	assert_eq(trace_rows[0]["operation"], &"quests.offer")
	assert_eq(trace_rows[0]["stage"], BoundaryTraceEntry.Stage.COMPLETED)
	assert_eq(trace_rows[1]["stage"], BoundaryTraceEntry.Stage.COMPLETED)
	assert_eq(trace_rows[2]["stage"], BoundaryTraceEntry.Stage.REJECTED)

	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_world.process(0.1)
	_world.process(0.1)
	assert_true(record.reward_paid)
	var reward_results: int = 0
	for row: Dictionary in BoundaryTrace.snapshots(String(record.quest_id)):
		if row["operation"] == &"quests.reward":
			reward_results += 1
			assert_eq(row["stage"], BoundaryTraceEntry.Stage.COMPLETED)
			assert_eq(row["correlation_id"], StringName("quest_reward/" + String(record.quest_id)))
	assert_eq(reward_results, 1)


## Предложение однократно связывает живую коробку с выдавшим задание торговцем.
func test_offer_is_idempotent_and_live_bindings_target_real_package_and_issuer() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_not_null(record)
	assert_eq(record.package_id, "durable:first")
	assert_eq(record.display_number, 3)
	assert_eq(record.deadline_day, 2)
	assert_eq(RefusalQuestService.offer(_trader), record)
	assert_eq(_state.records.size(), 1)

	var binding: Entity = _world.query.with_all([C_QuestBinding]).execute_one()
	var parcel_link: bool = false
	var issuer_link: bool = false
	for link: Relationship in binding.relationships:
		if link.relation is R_TargetsPackage:
			parcel_link = link.target == _parcel
		if link.relation is R_IssuedBy:
			issuer_link = link.target == _trader
	assert_true(parcel_link)
	assert_true(issuer_link)
	assert_true(RefusalQuestService.accept(record.quest_id))
	assert_false(RefusalQuestService.accept(record.quest_id))


## Фактический отказ игрока даёт одну награду и сохраняет обычный штраф обслуживания.
func test_actual_player_denial_completes_reward_once_and_preserves_normal_penalty() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.accept(record.quest_id))
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.DAY
	_visit.started = true
	assert_true(CustomerFlowService.deny(_visit.visit_id))
	assert_true(CustomerOutcomeService.declare(_visit, CustomerVisit.Declaration.REFUSED))
	CustomerOutcomeService.settle(_visit, _wallet, 2)
	assert_eq(_wallet.balance, 350)
	assert_eq(_wallet.penalties, 150)
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.COMPLETED)
	assert_true(record.reward_paid)
	assert_eq(_wallet.balance, 410)
	assert_eq(_wallet.penalties, 150, "Quest reward never waives the ordinary refusal consequences")
	assert_eq(_visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(_wallet.operations.size(), 2)
	_world.process(0.0)
	assert_eq(_wallet.balance, 410)
	assert_true(_world.query.with_all([C_QuestBinding]).execute().is_empty())


## Реальная выдача проваливает задание независимо от ложной записи отказа в терминале.
func test_actual_delivery_fails_without_reward_even_if_terminal_says_refused() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.accept(record.quest_id))
	var ready: PackageDeliveryCheck = PackageDeliveryCheck.new()
	ready.result = PackageDeliveryCheck.Result.READY
	assert_true(CustomerOutcomeService.receive(_visit, ready))
	_visit.declaration = CustomerVisit.Declaration.REFUSED
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.FAILED)
	assert_eq(_wallet.balance, 500)
	assert_false(record.reward_paid)


## Игнорирование окончательно закрывает предложение той же личности.
func test_ignored_offer_stays_terminal_and_is_not_issued_again_for_same_identity() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.ignore(record.quest_id))
	assert_false(RefusalQuestService.accept(record.quest_id))
	assert_eq(record.state, RefusalQuestRecord.State.IGNORED)
	assert_null(RefusalQuestService.offer(_trader))
	assert_eq(_state.records.size(), 1)
	assert_true(_world.query.with_all([C_QuestBinding]).execute().is_empty())


#endregion

#region Срок и сохранение истории
## Ночной срок завершает незакрытое задание; добровольный отказ клиента не заменяет отказ игрока.
func test_night_deadline_expires_unresolved_or_voluntary_refusal_and_late_denial() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.accept(record.quest_id))
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.EVENING
	_visit.actual = CustomerVisit.Actual.CUSTOMER_REFUSED
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.ACTIVE)
	_cycle.phase = C_DayCycle.Phase.NIGHT
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.EXPIRED)
	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_cycle.day_index = 3
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.EXPIRED)
	assert_eq(_wallet.balance, 500)


## Загруженное задание после срока не выдаёт награду за поздний отказ.
func test_loaded_active_quest_cannot_complete_after_deadline_from_late_actual_denial() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.accept(record.quest_id))
	_cycle.day_index = 3
	_visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.EXPIRED)
	assert_false(record.reward_paid)


## Повтор номера и удаление торговца не подменяют постоянную цель задания.
func test_reused_display_number_and_removed_issuer_do_not_replace_durable_target() -> void:
	var record: RefusalQuestRecord = RefusalQuestService.offer(_trader)
	assert_true(RefusalQuestService.accept(record.quest_id))
	var unrelated: CustomerVisit = CustomerVisit.new()
	unrelated.visit_id = &"visit/reused-number"
	unrelated.package_id = "durable:second"
	unrelated.actual = CustomerVisit.Actual.DELIVERED
	_flow.visits.append(unrelated)
	_world.remove_entity(_trader)
	_world.process(0.0)
	assert_eq(record.state, RefusalQuestRecord.State.ACTIVE)
	assert_eq(record.package_id, "durable:first")
	assert_eq(record.issuer_key, &"evening_trader")

	var copy: C_QuestSession = _state.duplicate(true) as C_QuestSession
	assert_eq(copy.records[0].visit_id, _visit.visit_id)
	copy.records[0].state = RefusalQuestRecord.State.FAILED
	assert_eq(record.state, RefusalQuestRecord.State.ACTIVE)

#endregion
