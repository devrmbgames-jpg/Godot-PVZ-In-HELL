extends CanvasLayer
## Package-centric warehouse terminal. Gameplay authority remains in package/customer/economy services.
class_name TerminalPanel

enum SortMode {
	WEIGHT,
	NUMBER,
	DATE,
	TYPE,
	PRICE,
}

enum InfoMode {
	DETAIL,
	PACKAGE_HISTORY,
	TRANSACTIONS,
	HELP,
}

const REFRESH_SECONDS: float = 0.25
const PACKAGE_LINE_SCENE_PATH: String = "res://content/ui/ui_terminal_package_line.tscn"
const SORT_ICON_ASCENDING_PATH: String = "res://addons/at-icons/control/file_arrow_up.svg"
const SORT_ICON_DESCENDING_PATH: String = "res://addons/at-icons/control/file_arrow_down.svg"

@onready var _sort_type: MenuButton = %ButtonMenuSortType
@onready var _sort_direction: Button = %ButtonSortUpDown
@onready var _show_archive_button: Button = %ButtonShowHideArchive
@onready var _package_list: VBoxContainer = %PackageList
@onready var _package_find: LineEdit = %PackageFind
@onready var _package_detail: UI_TerminalPackageDetailInfo = %PackageDetailInfo
@onready var _package_history: UI_TerminalLogHistory = %PanelLogHistory
@onready var _transaction_history: UI_TerminalLogHistory = %PanelLogTransaction
@onready var _show_history_button: Button = %ButtonShowHistory
@onready var _show_transactions_button: Button = %ButtonTransaction
@onready var _orders_button: Button = %ButtonOrders
@onready var _help_button: Button = %ButtonHelp

var _reader: Entity = null
var _package_line_scene: PackedScene = null
var _capture_token: int = 0
var _refresh_remaining: float = 0.0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _selected_package_id: String = ""
var _sort_mode: SortMode = SortMode.DATE
var _sort_ascending: bool = false
var _show_archive: bool = false
var _info_mode: InfoMode = InfoMode.DETAIL
var _last_data_signature: String = ""


#region Lifecycle
func _ready() -> void:
	visible = false
	_package_line_scene = load(PACKAGE_LINE_SCENE_PATH) as PackedScene
	assert(_package_line_scene != null)
	_clear_designer_rows()
	_sort_type.get_popup().id_pressed.connect(_on_sort_mode_selected)
	_sort_direction.pressed.connect(_on_sort_direction_pressed)
	_show_archive_button.toggled.connect(_on_archive_toggled)
	_package_find.text_changed.connect(_on_search_changed)
	_show_history_button.pressed.connect(_on_show_history_pressed)
	_show_transactions_button.pressed.connect(_on_show_transactions_pressed)
	_orders_button.pressed.connect(_on_orders_pressed)
	_help_button.pressed.connect(_on_help_pressed)
	_apply_sort_presentation()
	_set_info_mode(InfoMode.DETAIL)


func _exit_tree() -> void:
	close_panel()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var close_requested: bool = event.is_action_pressed(&"menu")
	if not _package_find.has_focus():
		close_requested = close_requested or event.is_action_pressed(&"interact")
	if close_requested:
		close_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_reader) or not GrabService.holder_available(_reader):
		close_panel()
		return
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh()
		_refresh_remaining = REFRESH_SECONDS
#endregion


#region Public UI API
func open_for(actor: Entity) -> void:
	if visible:
		_refresh(true)
		return
	_reader = actor
	_capture_token = InteractionControlFocus.acquire(
		actor,
		self,
		InteractionControlFocus.Priority.MODAL,
	)
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_refresh_remaining = 0.0
	_last_data_signature = ""
	_refresh(true)


func close_panel() -> void:
	if not visible:
		return
	visible = false
	InteractionControlFocus.release(_reader, _capture_token)
	_capture_token = 0
	_reader = null
	Input.mouse_mode = _previous_mouse_mode
#endregion


func _refresh(force: bool = false) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	_orders_button.disabled = CommerceService.current() == null or cycle == null or cycle.phase not in [C_DayCycle.Phase.MORNING, C_DayCycle.Phase.EVENING]
	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger == null:
		_clear_package_rows()
		_package_detail.clear_info()
		return

	var states: Dictionary[String, C_PackageState] = _live_states()
	var visits: Dictionary[String, CustomerVisit] = _visits_by_package()
	var signature: String = _data_signature(ledger, states, visits)
	if not force and signature == _last_data_signature:
		return
	_last_data_signature = signature
	_rebuild_package_rows(ledger, states, visits)
	_refresh_info(ledger, states, visits)


func _rebuild_package_rows(
	ledger: C_PackageLedger,
	states: Dictionary[String, C_PackageState],
	visits: Dictionary[String, CustomerVisit],
) -> void:
	_clear_package_rows()
	var records: Array[PackageRegistrationRecord] = _visible_records(ledger, states, visits)
	var selected_visible: bool = false
	for record: PackageRegistrationRecord in records:
		if record.package_id == _selected_package_id:
			selected_visible = true
			break
	if not selected_visible:
		_selected_package_id = records[0].package_id if not records.is_empty() else ""

	var cycle: C_DayCycle = DayPhaseService.current()
	var actions_enabled: bool = cycle != null and cycle.phase != C_DayCycle.Phase.NIGHT
	for record: PackageRegistrationRecord in records:
		var line: UI_TerminalButtonPackage = _package_line_scene.instantiate() as UI_TerminalButtonPackage
		_package_list.add_child(line)
		line.package_selected.connect(_on_package_selected)
		line.taken_requested.connect(_on_taken_requested)
		line.refused_requested.connect(_on_refused_requested)
		line.lost_requested.connect(_on_lost_requested)
		line.present(
			record,
			states.get(record.package_id) as C_PackageState,
			visits.get(record.package_id) as CustomerVisit,
			record.package_id == _selected_package_id,
			actions_enabled,
		)


func _visible_records(
	ledger: C_PackageLedger,
	states: Dictionary[String, C_PackageState],
	visits: Dictionary[String, CustomerVisit],
) -> Array[PackageRegistrationRecord]:
	var records: Array[PackageRegistrationRecord] = []
	var needle: String = _package_find.text.strip_edges().to_lower()
	for record: PackageRegistrationRecord in ledger.records:
		var visit: CustomerVisit = visits.get(record.package_id) as CustomerVisit
		if not _show_archive and _is_archived(record, visit):
			continue
		var state: C_PackageState = states.get(record.package_id) as C_PackageState
		if not needle.is_empty() and not _matches_search(record, state, visit, needle):
			continue
		records.append(record)
	records.sort_custom(_record_before)
	return records


func _matches_search(
	record: PackageRegistrationRecord,
	state: C_PackageState,
	visit: CustomerVisit,
	needle: String,
) -> bool:
	var definition: DEF_Package = record.definition
	var haystack: String = "%03d %s %s %s %s %s" % [
		record.number,
		record.package_id,
		record.history_id,
		definition.description if definition != null else "",
		definition.comment if definition != null else "",
		UI_TerminalButtonPackage.status_text(record, state, visit),
	]
	return needle in haystack.to_lower()


func _record_before(first: PackageRegistrationRecord, second: PackageRegistrationRecord) -> bool:
	var comparison: int = _compare_records(first, second)
	if comparison == 0:
		comparison = _compare_int(first.number, second.number)
	return comparison < 0 if _sort_ascending else comparison > 0


func _compare_records(first: PackageRegistrationRecord, second: PackageRegistrationRecord) -> int:
	var first_definition: DEF_Package = first.definition
	var second_definition: DEF_Package = second.definition
	match _sort_mode:
		SortMode.WEIGHT:
			return _compare_float(
				first_definition.mass_kg if first_definition != null else 0.0,
				second_definition.mass_kg if second_definition != null else 0.0,
			)
		SortMode.NUMBER:
			return _compare_int(first.number, second.number)
		SortMode.DATE:
			return _compare_int(first.day_index, second.day_index)
		SortMode.TYPE:
			var first_type: String = String(first_definition.key) if first_definition != null else ""
			var second_type: String = String(second_definition.key) if second_definition != null else ""
			return first_type.nocasecmp_to(second_type)
		SortMode.PRICE:
			return _compare_int(
				first_definition.accounting_value if first_definition != null else 0,
				second_definition.accounting_value if second_definition != null else 0,
			)
	return 0


static func _compare_int(first: int, second: int) -> int:
	if first < second:
		return -1
	if first > second:
		return 1
	return 0


static func _compare_float(first: float, second: float) -> int:
	if first < second:
		return -1
	if first > second:
		return 1
	return 0


static func _is_archived(
	record: PackageRegistrationRecord,
	visit: CustomerVisit,
) -> bool:
	if visit != null:
		return visit.declaration != CustomerVisit.Declaration.NONE
	return not record.active


func _refresh_info(
	ledger: C_PackageLedger,
	states: Dictionary[String, C_PackageState],
	visits: Dictionary[String, CustomerVisit],
) -> void:
	match _info_mode:
		InfoMode.DETAIL:
			var record: PackageRegistrationRecord = _record_for(ledger, _selected_package_id)
			if record == null:
				_package_detail.clear_info()
			else:
				_package_detail.present(
					record,
					states.get(record.package_id) as C_PackageState,
					visits.get(record.package_id) as CustomerVisit,
				)
		InfoMode.PACKAGE_HISTORY:
			_package_history.present(
				"История посылок",
				_package_history_entries(ledger, states, visits),
			)
		InfoMode.TRANSACTIONS:
			_transaction_history.present("Транзакции", _transaction_entries())
		InfoMode.HELP:
			_package_history.present("Справка", _help_entries())


func _package_history_entries(
	ledger: C_PackageLedger,
	states: Dictionary[String, C_PackageState],
	visits: Dictionary[String, CustomerVisit],
) -> PackedStringArray:
	var ordered: Array[PackageRegistrationRecord] = []
	for record: PackageRegistrationRecord in ledger.records:
		ordered.append(record)
	ordered.sort_custom(_history_record_before)
	var entries: PackedStringArray = []
	for record: PackageRegistrationRecord in ordered:
		var definition: DEF_Package = record.definition
		var title: String = (
			definition.description
			if definition != null and not definition.description.is_empty()
			else record.package_id
		)
		var uid: String = record.history_id if not record.history_id.is_empty() else "—"
		var state: C_PackageState = states.get(record.package_id) as C_PackageState
		var visit: CustomerVisit = visits.get(record.package_id) as CustomerVisit
		entries.append(
			"День %d · UID %s · №%03d\n%s · %s"
			% [
				record.day_index,
				uid,
				record.number,
				title,
				UI_TerminalButtonPackage.status_text(record, state, visit),
			]
		)
	return entries


static func _history_record_before(
	first: PackageRegistrationRecord,
	second: PackageRegistrationRecord,
) -> bool:
	if first.day_index != second.day_index:
		return first.day_index > second.day_index
	return first.number > second.number


func _transaction_entries() -> PackedStringArray:
	var wallet: C_Wallet = WalletService.current()
	if wallet == null:
		return PackedStringArray(["Кошелёк недоступен."])
	var entries: PackedStringArray = [
		"Баланс: %d · Штрафы: %d · Завершено смен: %d"
		% [wallet.balance, wallet.penalties, wallet.completed_days]
	]
	for index: int in range(wallet.operations.size() - 1, -1, -1):
		var operation: MoneyOperation = wallet.operations[index]
		var delta: int = operation.amount if _is_credit(operation.reason) else -operation.amount
		var context: String = (
			String(operation.settlement_id)
			if operation.settlement_id != &""
			else operation.note
		)
		entries.append(
			"День %d · %+d · %s%s"
			% [
				operation.day_index,
				delta,
				_reason_text(operation.reason),
				(" · " + context) if not context.is_empty() else "",
			]
		)
	return entries


static func _reason_text(reason: MoneyOperation.Reason) -> String:
	match reason:
		MoneyOperation.Reason.PAYMENT:
			return "Оплата за выдачу"
		MoneyOperation.Reason.PURCHASE:
			return "Покупка"
		MoneyOperation.Reason.VOLUNTARY_BUYOUT:
			return "Присвоение отказной посылки"
		MoneyOperation.Reason.LOST:
			return "Потеря"
		MoneyOperation.Reason.PLAYER_REFUSAL:
			return "Отказ игрока"
		MoneyOperation.Reason.CONFIRMED_FRAUD:
			return "Подтверждённая жалоба"
		MoneyOperation.Reason.MISSED_REGISTRATION:
			return "Не зарегистрирована вовремя"
		MoneyOperation.Reason.DEBUG_CREDIT:
			return "Debug начисление"
		MoneyOperation.Reason.DEBUG_DEBIT:
			return "Debug списание"
		MoneyOperation.Reason.DEBUG_PENALTY:
			return "Debug штраф"
		MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL:
			return "Debug отмена штрафа"
	return "Операция"


static func _is_credit(reason: MoneyOperation.Reason) -> bool:
	return (
		reason == MoneyOperation.Reason.PAYMENT
		or reason == MoneyOperation.Reason.DEBUG_CREDIT
		or reason == MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL
	)


static func _help_entries() -> PackedStringArray:
	return PackedStringArray([
		"Выберите зарегистрированную посылку слева, чтобы увидеть подробности.",
		"Три кнопки в строке — единственные Terminal outcome-действия: Забрали, Отказались, Потеряли.",
		"Поиск фильтрует список. Сортировку можно менять по весу, номеру, дате, типу и цене.",
		"Архив показывает записи, для которых outcome уже отмечен.",
		"Отказная посылка не выкупается и не возвращается кнопкой Terminal. Её будущий исход определяется физической утренней выгрузкой/машиной/трешером.",
		"Если due-посылку не зарегистрировать до следующего Morning, она автоматически считается потерянной с отдельным штрафом MISSED_REGISTRATION.",
	])


func _live_states() -> Dictionary[String, C_PackageState]:
	return PackageRegistrationService.live_states()


func _visits_by_package() -> Dictionary[String, CustomerVisit]:
	var result: Dictionary[String, CustomerVisit] = {}
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if flow == null:
		return result
	for visit: CustomerVisit in flow.visits:
		result[visit.package_id] = visit
	return result


func _data_signature(
	ledger: C_PackageLedger,
	states: Dictionary[String, C_PackageState],
	visits: Dictionary[String, CustomerVisit],
) -> String:
	var parts: PackedStringArray = []
	for record: PackageRegistrationRecord in ledger.records:
		var state: C_PackageState = states.get(record.package_id) as C_PackageState
		var visit: CustomerVisit = visits.get(record.package_id) as CustomerVisit
		parts.append(
			"%s:%s:%d:%d:%d:%d:%d:%d:%d"
			% [
				record.package_id,
				record.history_id,
				record.number,
				1 if record.active else 0,
				state.registration if state != null else -1,
				state.damage if state != null else -1,
				state.opening if state != null else -1,
				visit.actual if visit != null else -1,
				visit.declaration if visit != null else -1,
			]
		)
	var wallet: C_Wallet = WalletService.current()
	if wallet != null:
		parts.append("wallet:%d:%d:%d" % [wallet.balance, wallet.penalties, wallet.operations.size()])
	return "|".join(parts)


static func _record_for(
	ledger: C_PackageLedger,
	package_id: String,
) -> PackageRegistrationRecord:
	for record: PackageRegistrationRecord in ledger.records:
		if record.package_id == package_id:
			return record
	return null


func _clear_designer_rows() -> void:
	_clear_package_rows()


func _clear_package_rows() -> void:
	for child: Node in _package_list.get_children():
		_package_list.remove_child(child)
		child.queue_free()


func _set_info_mode(mode: InfoMode) -> void:
	_info_mode = mode
	_package_detail.visible = mode == InfoMode.DETAIL
	_package_history.visible = (
		mode == InfoMode.PACKAGE_HISTORY
		or mode == InfoMode.HELP
	)
	_transaction_history.visible = mode == InfoMode.TRANSACTIONS


func _on_package_selected(package_id: String) -> void:
	_selected_package_id = package_id
	_set_info_mode(InfoMode.DETAIL)
	_refresh(true)


func _on_taken_requested(package_id: String) -> void:
	_declare_package(package_id, CustomerVisit.Declaration.TAKEN)


func _on_refused_requested(package_id: String) -> void:
	_declare_package(package_id, CustomerVisit.Declaration.REFUSED)


func _on_lost_requested(package_id: String) -> void:
	_declare_package(package_id, CustomerVisit.Declaration.LOST)


func _declare_package(
	package_id: String,
	declaration: CustomerVisit.Declaration,
) -> void:
	var visits: Dictionary[String, CustomerVisit] = _visits_by_package()
	var visit: CustomerVisit = visits.get(package_id) as CustomerVisit
	if visit == null:
		return
	if not CustomerFlowService.declare(visit.visit_id, declaration):
		push_warning("Terminal declaration rejected for package %s" % package_id)
		return
	_last_data_signature = ""
	call_deferred("_refresh", true)


func _on_sort_mode_selected(id: int) -> void:
	if id < SortMode.WEIGHT or id > SortMode.PRICE:
		return
	match id:
		SortMode.WEIGHT:
			_sort_mode = SortMode.WEIGHT
		SortMode.NUMBER:
			_sort_mode = SortMode.NUMBER
		SortMode.DATE:
			_sort_mode = SortMode.DATE
		SortMode.TYPE:
			_sort_mode = SortMode.TYPE
		SortMode.PRICE:
			_sort_mode = SortMode.PRICE
	_apply_sort_presentation()
	_refresh(true)


func _on_sort_direction_pressed() -> void:
	_sort_ascending = not _sort_ascending
	_apply_sort_presentation()
	_refresh(true)


func _apply_sort_presentation() -> void:
	var labels: Array[String] = ["Весу", "Номеру", "Дате", "Типу", "Цене"]
	_sort_type.text = "Сортировать: %s" % labels[_sort_mode]
	var icon_path: String = (
		SORT_ICON_ASCENDING_PATH
		if _sort_ascending
		else SORT_ICON_DESCENDING_PATH
	)
	_sort_direction.icon = load(icon_path) as Texture2D
	_sort_direction.tooltip_text = (
		"От меньшего к большему"
		if _sort_ascending
		else "От большего к меньшему"
	)


func _on_archive_toggled(enabled: bool) -> void:
	_show_archive = enabled
	_refresh(true)


func _on_search_changed(_value: String) -> void:
	_refresh(true)


func _on_show_history_pressed() -> void:
	_set_info_mode(InfoMode.PACKAGE_HISTORY)
	_refresh(true)


func _on_show_transactions_pressed() -> void:
	_set_info_mode(InfoMode.TRANSACTIONS)
	_refresh(true)


func _on_help_pressed() -> void:
	_set_info_mode(InfoMode.HELP)
	_refresh(true)


func _on_orders_pressed() -> void:
	if not is_instance_valid(_reader) or CommerceService.current() == null:
		return
	var actor: Entity = _reader
	close_panel()
	CommercePanelService.open(actor, null, true)
