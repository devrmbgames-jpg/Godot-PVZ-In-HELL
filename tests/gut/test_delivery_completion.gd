extends "res://tests/gut/test_district_delivery.gd"
## Фактическая выдача у двери, финансовый результат и согласованная ночь без повторных последствий.

const SAVE_PATH: String = "user://gut_delivery_completion.pvzh"
const MISSING_SLOT: String = "user://gut_delivery_completion_missing/slot.pvzh"
const SERVICE_TREE: String = "res://content/ai/trees/bt_npc_service.tres"

#region Реальные участники и ночной снимок
## Удаляет только собственный тестовый слот после освобождения fixture.
func after_each() -> void:
	super.after_each()
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _job(visit: CustomerVisit) -> NpcHomeDelivery:
	for job: NpcHomeDelivery in _district.home_deliveries:
		if job.visit_id == visit.visit_id:
			return job
	return null

func _meeting(visit: CustomerVisit) -> E_DistrictNpc:
	var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	assert_true(NpcDeliveryOfferService.accept(_job(visit).job_id))
	assert_true(NpcHomeDeliveryService.knock(_player, _door(person.home_id)))
	body.place_at(DistrictPopulationService.position_for(person.home_id))
	(_player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	(body.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	assert_eq((body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	return body

func _handoff(body: E_DistrictNpc, visit: CustomerVisit) -> Entity:
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.READY)
	return parcel

func _night_session() -> Entity:
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.name = "Session"
	session.owner = _root
	(_player as Node).name = "Player"
	(_player as Node).owner = _root
	if not session.has_component(C_Autosave):
		session.add_component(C_Autosave.new())
	(session.get_component(C_Autosave) as C_Autosave).path = SAVE_PATH
	# Полный снимок хранит авторские определения, а не настройки одиночного теста.
	_district.definition = load("res://content/definitions/gameplay/npc/def_district_default.tres") as DEF_District
	for visit: CustomerVisit in CustomerFlowService.current().visits:
		visit.definition = (load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule).events[0].customer
	return session

func _sleep_request() -> void:
	_world.add_system(S_DayPhase.new())
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.SLEEP
	request.expected_day = 1
	request.expected_phase = C_DayCycle.Phase.EVENING
	assert_true(DayPhaseService.submit(request))
	_world.process(0.1)
	assert_eq(DayPhaseService.current().phase, C_DayCycle.Phase.NIGHT)
#endregion

#region Физическое вручение и расчёт
## Настоящая коробка принимается через обычную проверку; дерево закрывает встречу и платит дважды разными ключами.
func test_real_handoff_pays_agreed_bonus_once_through_tree() -> void:
	_district.definition.delivery_bargain_probability = 1.0
	var visit: CustomerVisit = _delivery_case(_district.people[0], "completion_success")
	var job: NpcHomeDelivery = _job(visit)
	assert_eq(NpcDeliveryOfferService.negotiate(job.job_id), NpcHomeDelivery.Bargain.ACCEPTED)
	var body: E_DistrictNpc = _meeting(visit)
	_handoff(body, visit)
	assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_null(CustomerFlowService.parcel_for(visit.package_id))
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	assert_eq(job.status, NpcHomeDelivery.Status.DELIVERED)
	assert_eq(WalletService.current().balance, 25)
	assert_eq(WalletService.current().operations.size(), 2)
	assert_true(visit.settlement_committed)
	assert_true(job.bonus_committed)
	assert_null(NpcHomeDeliveryService.meeting_for(body))
	assert_false(body.has_component(C_CustomerAgent))
	assert_true(NpcHomeDeliveryService.complete(job))
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_eq(WalletService.current().balance, 25)
	assert_eq(WalletService.current().operations.size(), 2)

## Отказ по состоянию проверяет предложенную коробку; предмет возвращён миру без выплаты или нового хватания.
func test_damage_refusal_keeps_physical_box_and_is_idempotent() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "completion_refusal")
	visit.definition.accepts_damaged = false
	var body: E_DistrictNpc = _meeting(visit)
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	(parcel.get_component(C_PackageState) as C_PackageState).damage = C_PackageState.Damage.DAMAGED
	_handoff(body, visit)
	assert_eq(visit.actual, CustomerVisit.Actual.CUSTOMER_REFUSED)
	assert_same(CustomerFlowService.parcel_for(visit.package_id), parcel)
	assert_null(GrabService.held_relationship(parcel))
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	var job: NpcHomeDelivery = _job(visit)
	assert_eq(job.status, NpcHomeDelivery.Status.REFUSED)
	assert_true(NpcHomeDeliveryService.complete(job))
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_false(job.bonus_committed)
	assert_eq(WalletService.current().balance, 0)
	assert_true(WalletService.current().operations.is_empty())

## Номер/регистрация/назначение и уничтожение проверяются до освобождения хвата и изменения факта выдачи.
func test_invalid_parcel_never_changes_home_outcome_or_money() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "completion_checks")
	var other: CustomerVisit = _delivery_case(_district.people[3], "completion_wrong")
	var body: E_DistrictNpc = _meeting(visit)
	var wrong: Entity = CustomerFlowService.parcel_for(other.package_id)
	wrong.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.WRONG_PACKAGE)
	GrabService.release(_player, wrong)
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	state.registration = C_PackageState.Registration.UNREGISTERED
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.UNREGISTERED)
	state.registration = C_PackageState.Registration.REGISTERED
	for binding: Relationship in parcel.relationships.duplicate():
		if binding.relation is R_AssignedTo:
			parcel.remove_relationship(binding)
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.UNASSIGNED)
	CustomerFlowService.bind_parcel(body, visit)
	state.damage = C_PackageState.Damage.DESTROYED
	assert_eq(CustomerFlowService.confirm_direct_delivery(_player, body), PackageDeliveryCheck.Result.DESTROYED)
	assert_not_null(GrabService.held_relationship(parcel))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_job(visit).status, NpcHomeDelivery.Status.ACCEPTED)
	assert_true(WalletService.current().operations.is_empty())

## Осмотр у своей двери сохраняет реальные резервы; принятие после осмотра платит через обычное завершение.
func test_home_inspection_acceptance_releases_all_cargo_before_bonus() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "completion_inspection")
	visit.definition.private_inspection = true
	visit.definition.inspection_keep_probability = 1.0
	visit.definition.inspection_unpack_probability = 0.0
	var body: E_DistrictNpc = _meeting(visit)
	var parcel: Entity = _handoff(body, visit)
	assert_same(CustomerInspectionService.owner_for(parcel), body)
	assert_not_null(PhysicalSlotService.relationship(parcel))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.RETURNING_FROM_BOOTH
	(body.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_true(_run_tree(body, SERVICE_TREE, 0.2))
	assert_eq(_job(visit).status, NpcHomeDelivery.Status.DELIVERED)
	assert_null(CustomerInspectionService.parcel_for(body))
	assert_null(NpcHomeDeliveryService.meeting_for(body))
	assert_eq(WalletService.current().operations.size(), 2)

## Сбой обычной оплаты не платит более дешёвую терминальную доплату и не готовит новое утро.
func test_failed_base_payment_waits_before_bonus_and_night_preparation() -> void:
	_district.definition.terminal_delivery_bonus = 1
	_delivery_case(_district.people[0], "minimum_for_payment")
	var visit: CustomerVisit = _delivery_case(_district.people[3], "base_payment")
	var body: E_DistrictNpc = _meeting(visit)
	_handoff(body, visit)
	var job: NpcHomeDelivery = _job(visit)
	var wallet: C_Wallet = WalletService.current()
	wallet.balance = WalletService.MAX_AMOUNT - 5
	assert_false(NpcHomeDeliveryService.complete(job))
	assert_false(visit.settlement_committed)
	assert_false(job.bonus_committed)
	assert_true(wallet.operations.is_empty())
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)

	var session: Entity = _night_session()
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	NightSaveService.process(session, cycle, state, 0.1)
	assert_false(cycle.night_ready)
	assert_eq(state.started_night, 0)
	assert_eq(_district.prepared_morning, 1)
	assert_false(FileAccess.file_exists(SAVE_PATH))
	wallet.balance = 0
	state.retry_remaining = 0.0
	NightSaveService.process(session, cycle, state, 0.1)
	assert_true(visit.settlement_committed)
	assert_true(job.bonus_committed)
	assert_eq(wallet.balance, 11)
	assert_eq(wallet.operations.size(), 2)
	assert_true(cycle.night_ready)

## Недоступный игрок не вызывает получателя и не создаёт резервирования встречи.
func test_unavailable_player_cannot_create_home_meeting() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "unavailable_knock")
	assert_true(NpcDeliveryOfferService.accept(_job(visit).job_id))
	_player.add_component(C_Death.new())
	assert_false(NpcHomeDeliveryService.knock(_player, _door(_district.people[0].home_id)))
	var body: E_DistrictNpc = DistrictPopulationService.body_for(visit.customer_id)
	assert_false(body.has_component(C_CustomerAgent))
	assert_null(NpcHomeDeliveryService.meeting_for(body))
#endregion

#region Невыполнение, ручная потеря и повтор ночи
## Прерванный осмотр можно продолжить до сна; отказ от продолжения не переносит коробку на склад.
func test_interrupted_meeting_can_retry_then_sleep_keeps_box_and_notes() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "interrupted_meeting")
	visit.definition.private_inspection = true
	var body: E_DistrictNpc = _meeting(visit)
	var parcel: Entity = _handoff(body, visit)
	NpcServiceRole.suspend(body)
	assert_null(CustomerInspectionService.owner_for(parcel))
	assert_null(PhysicalSlotService.relationship(parcel))
	assert_null(NpcHomeDeliveryService.meeting_for(body))
	assert_eq(_job(visit).status, NpcHomeDelivery.Status.ACCEPTED)
	assert_true(NpcHomeDeliveryService.knock(_player, _door(_district.people[0].home_id)))
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	NpcServiceRole.suspend(body)
	var pose: Transform3D = (parcel as Node as Node3D).global_transform
	assert_true(PackageHistoryService.update_note(visit.package_history_id, "Не забыть: обещал принести домой"))
	var session: Entity = _night_session()
	_sleep_request()
	var cycle: C_DayCycle = DayPhaseService.current()
	NightSaveService.process(session, cycle, session.get_component(C_Autosave) as C_Autosave, 0.1)
	assert_true(cycle.night_ready)
	assert_eq(_job(visit).status, NpcHomeDelivery.Status.FAILED)
	assert_eq((parcel as Node as Node3D).global_transform, pose)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(visit.arrival_day, 2)
	assert_true(WalletService.current().operations.is_empty())
	_world.process(0.1)
	assert_eq(cycle.day_index, 2)
	assert_eq(cycle.phase, C_DayCycle.Phase.MORNING)
	assert_true(CustomerFlowService.visit_due(visit, 2))
	assert_true(CustomerFlowService.arrival_allowed(visit))
	assert_null(NpcDeliveryOfferService.personal_for(visit.customer_id))
	assert_eq(PackageHistoryService.record_for(visit.package_id).note, "Не забыть: обещал принести домой")

## Ручной LOST закрывает случай; ночное невыполнение обещания не открывает этот заказ повторно.
func test_manual_loss_is_not_reopened_by_failed_delivery() -> void:
	var visit: CustomerVisit = _delivery_case(_district.people[0], "closed_loss")
	assert_true(NpcDeliveryOfferService.accept(_job(visit).job_id))
	assert_true(CustomerFlowService.declare(visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(visit.finished)
	var money_count: int = WalletService.current().operations.size()
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_true(visit.finished)
	assert_false(CustomerFlowService.visit_due(visit, 2))
	assert_eq(visit.declaration, CustomerVisit.Declaration.LOST)
	assert_eq(WalletService.current().operations.size(), money_count)

## Ошибка файла повторяет запись того же утра; память, коробка и заметки переживают восстановление.
func test_night_write_retry_restores_one_failed_promise_without_duplicate_box() -> void:
	var person: NpcRecord = _district.people[0]
	var visit: CustomerVisit = _delivery_case(person, "night_retry")
	assert_true(NpcDeliveryOfferService.accept(_job(visit).job_id))
	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	var pose: Transform3D = (parcel as Node as Node3D).global_transform
	var session: Entity = _night_session()
	_sleep_request()
	var cycle: C_DayCycle = DayPhaseService.current()
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = MISSING_SLOT
	NightSaveService.process(session, cycle, state, 0.1)
	assert_ne(state.last_error, OK)
	assert_false(cycle.night_ready)
	assert_eq(state.started_night, 1)
	assert_eq(person.memories.size(), 1)
	assert_eq(_job(visit).status, NpcHomeDelivery.Status.FAILED)
	assert_eq((parcel as Node as Node3D).global_transform, pose)
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	NightSaveService.process(session, cycle, state, 0.1)
	assert_true(cycle.night_ready)
	assert_eq(person.memories.size(), 1)
	assert_eq(cycle.day_index, 1)
	assert_true(WalletService.current().operations.is_empty())
	var saved: Dictionary = AutosaveStore.read(SAVE_PATH)
	assert_true(WorldSnapshotService.valid(saved, _root))
	assert_true(WorldSnapshotService.restore(saved, _root))
	_district = DistrictPopulationService.current()
	var restored: CustomerVisit = CustomerFlowService.find_visit(visit.visit_id)
	assert_eq(_job(restored).status, NpcHomeDelivery.Status.FAILED)
	assert_eq(DistrictPopulationService.person_for(person.npc_id).memories.size(), 1)
	assert_eq((CustomerFlowService.parcel_for(visit.package_id) as Node as Node3D).global_transform, pose)
	assert_eq(DayPhaseService.current().day_index, 2)
	assert_eq(_box_count(visit.package_id), 1)
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_eq(DistrictPopulationService.person_for(person.npc_id).memories.size(), 1)

## Считает реальные физические экземпляры одной посылки после восстановления.
func _box_count(package_id: String) -> int:
	var count: int = 0
	for parcel: Entity in _world.query.with_all([C_Package]).execute():
		if (parcel.get_component(C_Package) as C_Package).package_id == package_id:
			count += 1
	return count
#endregion
