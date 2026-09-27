extends CanvasLayer
## Read-only warehouse _registry view with its own modal control-capture token.
class_name TerminalPanel

const REFRESH_SECONDS: float = 0.2

@onready var _title: Label = $Root/Panel/Margin/Rows/Title
@onready var _registry: RichTextLabel = $Root/Panel/Margin/Rows/Registry
@onready var _close_button: Button = $Root/Panel/Margin/Rows/Close
@onready var _visits: OptionButton = $Root/Panel/Margin/Rows/Visits
@onready var _visit_summary: Label = $Root/Panel/Margin/Rows/VisitSummary
@onready var _action_feedback: Label = $Root/Panel/Margin/Rows/ActionFeedback
var _reader: Entity = null
var _capture_token: int = 0
var _refresh_remaining: float = 0.0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


#region Lifecycle
func _ready() -> void:
	visible = false
	_close_button.pressed.connect(close_panel)
	var rows: Node = $Root/Panel/Margin/Rows/Closeout
	(rows.get_node("Taken") as Button).pressed.connect(_declare_selected.bind(CustomerVisit.Declaration.TAKEN))
	(rows.get_node("Refused") as Button).pressed.connect(_declare_selected.bind(CustomerVisit.Declaration.REFUSED))
	(rows.get_node("Lost") as Button).pressed.connect(_declare_selected.bind(CustomerVisit.Declaration.LOST))
	(rows.get_node("Deny") as Button).pressed.connect(_deny_selected)
	(rows.get_node("Buyout") as Button).pressed.connect(_dispose_selected.bind(true))
	(rows.get_node("Return") as Button).pressed.connect(_dispose_selected.bind(false))
	_visits.item_selected.connect(_select_visit)


func _exit_tree() -> void:
	close_panel()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"menu")):
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
## Opens the _registry without changing held-item ownership.
func open_for(actor: Entity) -> void:
	if visible:
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
	_refresh()
	_close_button.grab_focus()


## Releases only this panel's capture and restores its previous cursor mode.
func close_panel() -> void:
	if not visible:
		return
	visible = false
	InteractionControlFocus.release(_reader, _capture_token)
	_capture_token = 0
	_reader = null
	Input.mouse_mode = _previous_mouse_mode
#endregion


func get_registry_text() -> String:
	return _registry.text


func _refresh() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle != null:
		_title.text = "СКЛАДСКОЙ РЕЕСТР · ДЕНЬ %d" % cycle.day_index
		_registry.text = _economy_text(cycle) + PackageRegistrationService.terminal_text()
	_refresh_visits()


func _economy_text(cycle: C_DayCycle) -> String:
	var wallet: C_Wallet = WalletService.current()
	if wallet == null:
		return ""
	var summary: String = "Баланс: %d · Штрафы всего: %d · Завершено смен: %d\n" % [
		wallet.balance, wallet.penalties, wallet.completed_days,
	]
	for daily: DailyMoneyResult in wallet.daily_results:
		if daily.day_index == cycle.day_index:
			summary += "За день: доход %d · покупки/выкуп %d · штрафы %d\n" % [
				daily.income, daily.spending, daily.penalties,
			]
	return summary + "\n"


func _selected_visit_id() -> StringName:
	if _visits.selected < 0:
		return &""
	return StringName(_visits.get_item_metadata(_visits.selected))


func _refresh_visits() -> void:
	var selected: StringName = _selected_visit_id()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	_visits.clear()
	if flow == null:
		return
	for visit: CustomerVisit in flow.visits:
		if not visit.started:
			continue
		var index: int = _visits.item_count
		_visits.add_item("%s · %s" % [visit.definition.display_name, visit.package_id])
		_visits.set_item_metadata(index, visit.visit_id)
		if selected == visit.visit_id or (selected == &"" and not visit.finished):
			_visits.select(index)
	_select_visit(_visits.selected)


func _select_visit(_index: int) -> void:
	var visit: CustomerVisit = CustomerFlowService.find_visit(_selected_visit_id())
	_visit_summary.text = CustomerPresentation.visit_text(visit) if visit != null else "Клиентов пока нет. Начните смену."


func _declare_selected(declaration: CustomerVisit.Declaration) -> void:
	var accepted: bool = CustomerFlowService.declare(_selected_visit_id(), declaration)
	_action_feedback.text = "Отметка сохранена. Факт выдачи хранится отдельно." if accepted else "Отметку изменить нельзя или визит недоступен."
	_refresh()


func _deny_selected() -> void:
	var accepted: bool = CustomerFlowService.deny(_selected_visit_id())
	_action_feedback.text = "Клиенту отказано. Отметьте исход: Отказался, Потеряна или Забрал." if accepted else "Отказ недоступен для этого визита."
	_refresh()


func _dispose_selected(buyout: bool) -> void:
	var accepted: bool = CustomerFlowService.dispose_refusal(_selected_visit_id(), buyout)
	_action_feedback.text = "Посылка выкуплена." if buyout else "Посылка возвращена. Жалобы сохраняются."
	if not accepted:
		_action_feedback.text = "Нужна отказная посылка. Для возврата принесите её на стойку следующим утром."
	_refresh()
