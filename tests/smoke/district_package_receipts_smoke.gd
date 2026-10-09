extends Node
## Реальная утренняя поставка, строки терминала, ручной LOST и просрочка следующего дня.

const MAX_DELIVERY_FRAMES: int = 900
const EXPECTED_BATCH_SIZE: int = 5

var _failed: bool = false

#region Ограниченная приёмка
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var ledger: C_PackageLedger = PackageQueries.ledger()
	for frame: int in MAX_DELIVERY_FRAMES:
		await get_tree().physics_frame
		if flow.visits.size() == EXPECTED_BATCH_SIZE:
			break
	_check(flow.visits.size() == EXPECTED_BATCH_SIZE, "real morning shipment cases")
	_check(ledger.records.size() == EXPECTED_BATCH_SIZE, "receipt for every delivered box before scanning")
	if flow.visits.size() != EXPECTED_BATCH_SIZE or ledger.records.size() != EXPECTED_BATCH_SIZE:
		get_tree().quit(1)
		return
	level.set_physics_process(false)
	for record: PackageRegistrationRecord in ledger.records:
		_check(record.number == 0 and record.day_index == 0 and record.received_day == 1, "receipt has no issuance number")
		_check(not record.history_id.is_empty(), "stable receipt history")
		_check(not CustomerFlowQueries.package_declared_lost(record.package_id), "arrival does not fabricate loss")

	var first: CustomerVisit = flow.visits[0]
	var missing: Entity = PackageQueries.find_live_package(first.package_id)
	_check(missing != null and not first.started, "real unregistered parcel before visit")
	ECS.world.remove_entity(missing)
	var panel: TerminalPanel = level.get_node("Entityes/Terminal/TerminalPanel") as TerminalPanel
	panel._refresh(true)
	var rows: VBoxContainer = panel.get_node("%PackageList") as VBoxContainer
	_check(rows.get_child_count() == EXPECTED_BATCH_SIZE, "terminal keeps physically absent box")
	var missing_row: UI_TerminalButtonPackage = null
	for node: Node in rows.get_children():
		var row: UI_TerminalButtonPackage = node as UI_TerminalButtonPackage
		if row.package_id() == first.package_id:
			missing_row = row
	_check(missing_row != null, "missing receipt selectable")
	if missing_row != null:
		_check((missing_row.get_node("%LabelNumber") as Label).text == "Без номера", "terminal does not show number zero")
		var loss_button: Button = missing_row.get_node("%ButtonLost") as Button
		_check(not loss_button.disabled, "manual loss available before visit")
		loss_button.pressed.emit()
		_check(first.declaration == CustomerVisit.Declaration.LOST and first.finished and not first.started, "real terminal signal declares loss without NPC")
		_check(first.actual == CustomerVisit.Actual.NOT_RESOLVED, "declaration does not invent actual refusal or issuance")
	var wallet: C_Wallet = WalletService.current()
	var balance_after_loss: int = wallet.balance
	panel._on_lost_requested(first.package_id)
	_check(wallet.balance == balance_after_loss and wallet.operations.size() == 1, "terminal retry cannot repeat loss fee")
	panel._show_archive = true
	panel._refresh(true)
	_check(rows.get_child_count() == EXPECTED_BATCH_SIZE, "declared loss remains in terminal archive")

	var second: CustomerVisit = flow.visits[1]
	var second_parcel: Entity = PackageQueries.find_live_package(second.package_id)
	var second_record: PackageRegistrationRecord = PackageHistoryService.record_for(second.package_id)
	_check(PackageRegistrationService.register_package(second_parcel).outcome == PackageScanResult.Outcome.REGISTERED, "scanner upgrades receipt")
	_check(second_record.number == 1 and ledger.records.size() == EXPECTED_BATCH_SIZE, "registration keeps one row per box")
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	var future: CustomerVisit = flow.visits[2]
	_check(future.arrival_day > cycle.day_index, "authored delayed order is not due next morning")
	var overdue: CustomerVisit = flow.visits[3]
	var overdue_parcel: Entity = PackageQueries.find_live_package(overdue.package_id)
	_check(CustomerFlowFixture.morning(flow, cycle, wallet) == 2, "next morning records only unresolved unregistered due receipts")
	_check(overdue.registration_overdue_day == 2 and future.registration_overdue_day == 0, "deadline follows authored order date")
	_check(overdue.declaration == CustomerVisit.Declaration.NONE and overdue.actual == CustomerVisit.Actual.NOT_RESOLVED and not overdue.finished, "overdue is separate from declaration")
	_check(PackageQueries.find_live_package(overdue.package_id) == overdue_parcel, "morning does not delete overdue box")
	var balance_after_overdue: int = wallet.balance
	_check(CustomerFlowFixture.morning(flow, cycle, wallet) == 0, "morning retry has no new fact")
	_check(wallet.balance == balance_after_overdue and wallet.operations.size() == 3, "morning retry has no duplicate fine")
	_check(second.registration_overdue_day == 0, "registered box does not get overdue penalty")
	print("District package receipts smoke: ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Receipts smoke: " + message)
#endregion
