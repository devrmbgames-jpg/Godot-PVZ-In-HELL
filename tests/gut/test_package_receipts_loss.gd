extends GutTest
## Поступление, сканирование, ручная потеря и просрочка с реальным журналом World и терминалом.

var _world: World = null
var _flow: C_CustomerFlow = null
var _cycle: C_DayCycle = null
var _ledger: C_PackageLedger = null
var _wallet: C_Wallet = null
var _visit: CustomerVisit = null
var _package_definition: DEF_Package = null

#region Окружение
## Создаёт минимальную сессию с авторскими определениями, пригодными для codec round-trip.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_flow = C_CustomerFlow.new()
	_cycle = C_DayCycle.new()
	_ledger = C_PackageLedger.new()
	_wallet = C_Wallet.new()
	var schedule: DEF_CustomerSchedule = load("res://content/domains/customers/definitions/def_customer_schedule_default.tres") as DEF_CustomerSchedule
	_package_definition = schedule.supply.packages[0]
	_visit = CustomerVisit.new()
	_visit.visit_id = &"visit/receipt"
	_visit.package_id = "receipt"
	_visit.customer_id = &"recipient"
	_visit.definition = schedule.events[0].customer
	_visit.accounting_value = 100
	_visit.payment = 100
	_flow.visits.append(_visit)
	var session: Entity = Entity.new()
	session.component_resources = [_flow, _cycle, _ledger, _wallet]
	_world.add_entity(session)
	# GECS создаёт экземпляры компонентов; проверяем владельцев живого World, а не шаблоны.
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_ledger = session.get_component(C_PackageLedger) as C_PackageLedger
	_wallet = session.get_component(C_Wallet) as C_Wallet


## Удаляет только тестовое окружение, не меняя файлы сохранения игры.
func after_each() -> void:
	_world.free()
	ECS.world = null


func _parcel(package_id: String = "receipt") -> Entity:
	var parcel: Entity = Entity.new()
	var identity: C_Package = C_Package.new()
	identity.package_id = package_id
	identity.definition = _package_definition
	identity.delivery_day = 1
	parcel.component_resources = [identity, C_PackageState.new()]
	EntityCompositionFixture.register(_world, parcel)
	return parcel


func _next_morning(day_index: int = 2) -> int:
	_cycle.day_index = day_index
	_cycle.phase = C_DayCycle.Phase.MORNING
	return CustomerFlowFixture.morning(_flow, _cycle, _wallet)
#endregion

#region Поступление и сканирование
## Поступление не создаёт номера выдачи, не открывает визит и не меняет физическое состояние.
func test_arrival_is_stable_unregistered_record_without_counter_arrival() -> void:
	var parcel: Entity = _parcel()
	var record: PackageRegistrationRecord = PackageHistoryService.record_arrival(parcel, 1)
	assert_not_null(record)
	assert_eq(PackageHistoryService.record_arrival(parcel, 2), record)
	assert_eq(_ledger.records.size(), 1)
	assert_eq(record.received_day, 1)
	assert_eq(record.day_index, 0)
	assert_eq(record.number, 0)
	assert_not_null(PackageHistoryId.parse(record.history_id))
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	assert_eq(state.registration, C_PackageState.Registration.UNREGISTERED)
	assert_eq(state.scan, C_PackageState.Scan.NOT_SCANNED)
	assert_eq(state.registration_number, 0)
	assert_false(CustomerFlowQueries.arrival_allowed(_visit))
	assert_eq(CustomerPresentation.registered_number(_visit), -1)
	assert_eq(PackageRegistrationService.smallest_free_number(_ledger), 1)


## Сканер обновляет ту же запись; следующий номер не зависит от количества поступлений без номера.
func test_scanning_upgrades_existing_receipt_once_and_preserves_history() -> void:
	var parcel: Entity = _parcel()
	var record: PackageRegistrationRecord = PackageHistoryService.record_arrival(parcel, 1)
	var history_id: String = record.history_id
	PackageHistoryService.record_arrival(_parcel("second"), 1)
	_cycle.day_index = 2
	assert_eq(PackageRegistrationService.register_package(parcel).outcome, PackageScanResult.Outcome.REGISTERED)
	assert_eq(_ledger.records.size(), 2)
	assert_eq(_ledger.records[0], record)
	assert_eq(record.number, 1)
	assert_eq(record.received_day, 1)
	assert_eq(record.day_index, 2)
	assert_eq(record.history_id, history_id)
	assert_true(CustomerFlowQueries.arrival_allowed(_visit))
	assert_eq(PackageRegistrationService.register_package(parcel).outcome, PackageScanResult.Outcome.ALREADY_REGISTERED)
	assert_eq(PackageRegistrationService.smallest_free_number(_ledger), 2)


## Доверенная регистрация коробки без записи поступления также создаёт единственную историю.
func test_direct_registration_records_arrival_without_second_row() -> void:
	var parcel: Entity = _parcel()
	assert_eq(PackageRegistrationService.register_package(parcel).outcome, PackageScanResult.Outcome.REGISTERED)
	assert_eq(_ledger.records.size(), 1)
	assert_eq(_ledger.records[0].received_day, 1)
	assert_eq(_ledger.records[0].number, 1)
	assert_eq(PackageHistoryService.record_arrival(parcel, 1), _ledger.records[0])
#endregion

#region Ручная потеря и просрочка
## Уничтоженная незарегистрированная коробка остаётся известной; ранний LOST закрывает будущий приход.
func test_destroyed_unregistered_box_can_be_declared_lost_before_visit_once() -> void:
	var parcel: Entity = _parcel()
	var record: PackageRegistrationRecord = PackageHistoryService.record_arrival(parcel, 1)
	(parcel.get_component(C_PackageState) as C_PackageState).damage = C_PackageState.Damage.DESTROYED
	_world.remove_entity(parcel)
	assert_eq(PackageHistoryService.record_for("receipt"), record)
	assert_false(CustomerFlowQueries.package_declared_lost("receipt"))
	assert_false(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	assert_false(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.REFUSED))
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(CustomerFlowQueries.package_declared_lost("receipt"))
	assert_eq(record.number, 0)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(_visit.loss_cause, CustomerVisit.LossCause.DECLARED_LOST)
	assert_true(_visit.finished)
	assert_false(_visit.started)
	assert_eq(CustomerFlowQueries.actionable_remaining(_flow, 1), 0)
	assert_eq(_wallet.balance, -120)
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_next_morning(), 0)
	assert_eq(_wallet.balance, -120)


## Запланированный заказ до реального поступления не даёт раннего заявления или штрафа за регистрацию.
func test_unreceived_order_cannot_be_declared_lost_or_overdue() -> void:
	assert_false(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(_next_morning(), 0)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(_visit.registration_overdue_day, 0)
	assert_true(_wallet.operations.is_empty())


## После регистрации потеря тоже ручная; отсутствие тела не освобождает номер и не стирает строку.
func test_registered_destroyed_box_keeps_history_and_number_until_manual_loss() -> void:
	var parcel: Entity = _parcel()
	PackageRegistrationService.register_package(parcel)
	_world.remove_entity(parcel)
	assert_eq(_next_morning(), 0)
	assert_false(CustomerFlowQueries.package_declared_lost("receipt"))
	assert_eq(PackageRegistrationService.smallest_free_number(_ledger), 2)
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(_ledger.records.size(), 1)
	assert_true(_ledger.records[0].active)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_wallet.balance, -120)


## Просрочка отсутствующей коробки отдельна от LOST; последующая потеря не дублирует взысканную стоимость.
func test_missing_unregistered_box_is_overdue_without_automatic_loss_or_repeated_penalty() -> void:
	var parcel: Entity = _parcel()
	PackageHistoryService.record_arrival(parcel, 1)
	_world.remove_entity(parcel)
	assert_eq(_next_morning(), 1)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(_visit.finished)
	assert_false(_visit.settlement_committed)
	assert_eq(_visit.registration_money_delta, -300)
	assert_eq(_wallet.operations[0].reason, MoneyOperation.Reason.MISSED_REGISTRATION)
	assert_eq(_next_morning(3), 0)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_wallet.balance, -300)
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(_visit.settlement_committed)
	assert_eq(_visit.money_delta, 0)
	assert_eq(_wallet.balance, -300)
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(_wallet.operations.size(), 2)


## При настроенной меньшей ставке просрочки LOST взыскивает только остаток до обычной стоимости потери.
func test_manual_loss_charges_only_remaining_value_when_overdue_rate_is_lower() -> void:
	_wallet.policy = _wallet.policy.duplicate() as DEF_Economy
	_wallet.policy.missed_registration_percent = 50
	PackageHistoryService.record_arrival(_parcel(), 1)
	assert_eq(_next_morning(), 1)
	assert_eq(_wallet.balance, -50)
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(_wallet.balance, -120)
	assert_eq(_wallet.operations[1].amount, 70)
	assert_eq(_visit.registration_money_delta, -50)
	assert_eq(_visit.money_delta, -70)


## Поздняя регистрация допускает обычное получение и оплату независимо от уже взысканной просрочки.
func test_late_registration_keeps_real_delivery_and_payment_available() -> void:
	var parcel: Entity = _parcel()
	PackageHistoryService.record_arrival(parcel, 1)
	assert_eq(_next_morning(), 1)
	assert_eq(PackageRegistrationService.register_package(parcel).outcome, PackageScanResult.Outcome.REGISTERED)
	assert_true(CustomerFlowQueries.arrival_allowed(_visit))
	_visit.started = true
	var check_result: PackageDeliveryCheck = CustomerOutcomeService.check(
		_visit, parcel.get_component(C_Package) as C_Package,
		parcel.get_component(C_PackageState) as C_PackageState, true, false,
	)
	assert_true(CustomerOutcomeService.receive(_visit, check_result))
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.TAKEN))
	assert_eq(_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_eq(_visit.money_delta, 100)
	assert_eq(_wallet.balance, -200)
	assert_eq(_wallet.operations.size(), 2)


## Недоступный кошелёк не превращает просрочку в потерю; расчёт повторяется после восстановления сервиса.
func test_overdue_penalty_retries_without_repeating_fact_when_wallet_becomes_available() -> void:
	var parcel: Entity = _parcel()
	PackageHistoryService.record_arrival(parcel, 1)
	_cycle.day_index = 2
	assert_eq(CustomerFlowFixture.morning(_flow, _cycle, null), 1)
	assert_false(_visit.registration_penalty_committed)
	PackageRegistrationService.register_package(parcel)
	_cycle.day_index = 3
	CustomerOutcomeService.settle(_visit, _wallet, 3)
	CustomerOutcomeService.settle(_visit, _wallet, 3)
	assert_eq(_visit.registration_overdue_day, 2)
	assert_eq(_visit.registration_penalty_day, 3)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)


## Найденная после заявления коробка не получает новый номер и не открывает уже закрытый заказ.
func test_manual_loss_does_not_resurrect_order_when_box_is_found() -> void:
	var parcel: Entity = _parcel()
	PackageHistoryService.record_arrival(parcel, 1)
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(PackageRegistrationService.register_package(parcel).outcome, PackageScanResult.Outcome.REJECTED)
	assert_eq(_ledger.records[0].number, 0)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.LOST)
	assert_true(_visit.finished)
#endregion

#region Постоянные данные и UI
## Round-trip журнала, визита и кошелька сохраняет поступление без тела и однократный штраф.
func test_receipt_and_overdue_round_trip_preserves_missing_box_and_financial_history() -> void:
	var parcel: Entity = _parcel()
	PackageHistoryService.record_arrival(parcel, 1)
	_world.remove_entity(parcel)
	_next_morning()
	var history_id: String = _ledger.records[0].history_id
	assert_true(SaveDataCodec.apply_fields(_ledger, SaveDataCodec.component_data(_ledger).fields as Dictionary))
	assert_true(SaveDataCodec.apply_fields(_flow, SaveDataCodec.component_data(_flow).fields as Dictionary))
	assert_true(SaveDataCodec.apply_fields(_wallet, SaveDataCodec.component_data(_wallet).fields as Dictionary))
	_visit = _flow.visits[0]
	assert_eq(_ledger.records[0].history_id, history_id)
	assert_eq(_ledger.records[0].received_day, 1)
	assert_eq(_ledger.records[0].day_index, 0)
	assert_eq(_ledger.records[0].number, 0)
	assert_eq(_visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(_visit.registration_overdue_day, 2)
	assert_eq(_visit.registration_penalty_day, 2)
	assert_eq(_next_morning(3), 0)
	assert_eq(_wallet.operations.size(), 1)
	assert_null(PackageQueries.find_live_package("receipt"))
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_true(SaveDataCodec.apply_fields(_flow, SaveDataCodec.component_data(_flow).fields as Dictionary))
	assert_true(CustomerFlowService.declare(_visit.visit_id, CustomerVisit.Declaration.LOST))
	assert_eq(_wallet.operations.size(), 2)
	assert_eq(_wallet.balance, -300)


## Реальные сцены показывают «Без номера» и разрешают только LOST до начала визита.
func test_terminal_row_and_details_show_receipt_without_fabricated_number_or_registration_day() -> void:
	var record: PackageRegistrationRecord = PackageHistoryService.record_arrival(_parcel(), 1)
	var line: UI_TerminalButtonPackage = (load("res://content/ui/ui_terminal_package_line.tscn") as PackedScene).instantiate() as UI_TerminalButtonPackage
	add_child(line)
	line.present(record, null, _visit, false)
	assert_eq((line.get_node("%LabelNumber") as Label).text, "Без номера")
	assert_false((line.get_node("%ButtonLost") as Button).disabled)
	assert_true((line.get_node("%ButtonOK") as Button).disabled)
	assert_true((line.get_node("%ButtonCancel") as Button).disabled)
	assert_eq(UI_TerminalButtonPackage.status_text(record, null, _visit), "НЕ ЗАРЕГИСТРИРОВАНА")
	var detail: UI_TerminalPackageDetailInfo = (load("res://content/ui/ui_terminal_package_detail_info.tscn") as PackedScene).instantiate() as UI_TerminalPackageDetailInfo
	add_child(detail)
	detail.present(record, null, _visit)
	var description: RichTextLabel = detail.get_node("%RichTextLabelDescription") as RichTextLabel
	assert_true("Дата поступления: день 1" in description.text)
	assert_false("день 0" in description.text)
	_next_morning()
	assert_eq(UI_TerminalButtonPackage.status_text(record, null, _visit), "ПРОСРОЧЕНА РЕГИСТРАЦИЯ")
	detail.present(record, null, _visit)
	assert_true("Штраф за просрочку регистрации: 300" in description.text)
	line.present(record, null, _visit, false, false)
	assert_true((line.get_node("%ButtonLost") as Button).disabled)
	line.free()
	detail.free()
#endregion
