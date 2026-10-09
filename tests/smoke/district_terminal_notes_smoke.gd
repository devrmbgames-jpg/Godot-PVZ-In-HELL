extends Node
## Два процесса: ввод заметки в настоящем терминале, снимок отсутствующей коробки и восстановление UI.

const SAVE_PATH: String = "user://district_terminal_notes_smoke.pvzh"
const NOTE_TEXT: String = "[b]Не трогать[/b]\nвторая строка примечания"
const COMPLAINT_TEXT: String = "Где моя посылка, бездельник? [url=secret]Ответь![/url]"
const MAX_DELIVERY_FRAMES: int = 900
const EXPECTED_BATCH_SIZE: int = 5

var _failed: bool = false

#region Двухпроцессная приёмка
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup_slot()
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	if restoring:
		var data: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(not data.is_empty(), "test snapshot exists")
		_check(WorldSnapshotService.valid(data, level), "full saved world passes validation")
		if _failed:
			get_tree().quit(1)
			return
		_check(WorldSnapshotService.restore(data, level), "full saved world restored")
	else:
		for frame: int in MAX_DELIVERY_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowQueries.current().visits.size() == EXPECTED_BATCH_SIZE:
				break
	level.set_physics_process(false)
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	_check(flow.visits.size() == EXPECTED_BATCH_SIZE, "five real received orders")
	if flow.visits.is_empty():
		get_tree().quit(1)
		return
	var visit: CustomerVisit = flow.visits[0]
	var panel: TerminalPanel = level.get_node("Entityes/Terminal/TerminalPanel") as TerminalPanel
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	panel.open_for(actor)
	panel._on_package_selected(visit.package_id)
	var detail: UI_TerminalPackageDetailInfo = panel.get_node("%PackageDetailInfo") as UI_TerminalPackageDetailInfo
	var editor: TextEdit = detail.get_node("MarginContainer/VBoxContainer/TextEdit") as TextEdit
	var record: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
	if not restoring:
		editor.insert_text_at_caret(NOTE_TEXT)
		editor.set_caret_line(1)
		editor.set_caret_column(5)
		editor.grab_focus()
		var interact: InputEventAction = InputEventAction.new()
		interact.action = &"interact"
		interact.pressed = true
		panel._input(interact)
		_check(panel.visible, "typing interaction key does not close terminal")
		panel._refresh(true)
		_check(record.note == NOTE_TEXT, "real input updated persistent journal")
		_check(editor.get_caret_line() == 1 and editor.get_caret_column() == 5, "refresh preserved caret")
		_check(CustomerVisitLifecycle.create_complaint(visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true), "real resident complaint created")
		visit.complaint.message = COMPLAINT_TEXT
		ECS.world.remove_entity(PackageQueries.find_live_package(visit.package_id))
		panel.close_panel()
		panel.open_for(actor)
		_check(editor.text == NOTE_TEXT and editor.get_caret_column() == 5, "close and reopen preserved note and caret")
		panel.close_panel()
		var snapshot: Dictionary = WorldSnapshotService.capture(level, 1)
		_check(WorldSnapshotService.valid(snapshot, level), "captured world valid with absent parcel")
		_check(AutosaveStore.write(snapshot, SAVE_PATH) == OK, "test snapshot written")
	else:
		_check(record.note == NOTE_TEXT and editor.text == NOTE_TEXT, "note restored after process restart")
		_check(visit.complaint != null and visit.complaint.message == COMPLAINT_TEXT, "complaint text restored after process restart")
		_check(PackageQueries.find_live_package(visit.package_id) == null, "missing parcel not resurrected")
		var description: RichTextLabel = detail.get_node("%RichTextLabelDescription") as RichTextLabel
		_check(COMPLAINT_TEXT in description.get_parsed_text(), "complaint rendered literally")
		_check(visit.complaint.customer_name in description.get_parsed_text(), "saved resident name shown")
		_cleanup_slot()
	print("District terminal notes smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _cleanup_slot() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Terminal notes smoke: " + message)
#endregion
