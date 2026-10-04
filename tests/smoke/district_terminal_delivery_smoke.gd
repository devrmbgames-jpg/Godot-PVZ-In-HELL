extends Node
## Реальные кнопки, границы знаний и чтение уведомлений проверяются в двух headless-процессах.

const SAVE_PATH: String = "user://district_terminal_delivery_smoke.pvzh"
const MAX_RECEIVING_FRAMES: int = 900
const EXPECTED_BATCH_SIZE: int = 5
const COMPLAINT_TEXT: String = "Не получил коробку. Разберитесь с доставкой!"

var _failed: bool = false

#region Проверка терминала и полного снимка
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
		var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(not snapshot.is_empty() and WorldSnapshotService.valid(snapshot, level), "stored full world valid")
		if _failed:
			get_tree().quit(1)
			return
		_check(WorldSnapshotService.restore(snapshot, level), "full world restored")
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE:
				break
	level.set_physics_process(false)
	var district: C_District = DistrictPopulationService.current()
	if not restoring:
		district.definition = district.definition.duplicate() as DEF_District
		district.definition.terminal_delivery_minimum = 3
		district.definition.terminal_delivery_maximum = 3
		district.definition.personal_delivery_probability = 0.0
		district.delivery_offer_day = 0
		district.terminal_offer_target = 0
		district.delivery_considered.clear()
		for visit: CustomerVisit in CustomerFlowService.current().visits:
			_check(PackageRegistrationService.register_package(CustomerFlowService.parcel_for(visit.package_id)).outcome == PackageScanResult.Outcome.REGISTERED, "real received parcel registered")
	var private_job: NpcHomeDelivery = null
	var terminal_jobs: Array[NpcHomeDelivery] = []
	for job: NpcHomeDelivery in district.home_deliveries:
		if job.source == NpcHomeDelivery.Source.PERSONAL:
			private_job = job
		else:
			terminal_jobs.append(job)
	_check(private_job != null and terminal_jobs.size() >= 2, "private and two terminal offers exist")
	if _failed:
		get_tree().quit(1)
		return
	var panel: TerminalPanel = level.get_node("Entityes/Terminal/TerminalPanel") as TerminalPanel
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	panel._selected_package_id = private_job.package_id
	panel.open_for(actor)
	if not restoring:
		_check(NpcDeliveryOfferService.assign_personal(private_job.visit_id, &"ui_private_trap") == private_job, "private scenario assigned without new ID")
		_check(NpcDeliveryOfferService.accept(private_job.job_id), "private promise accepted")
		panel._refresh(true)
	_check(not (_line(panel, private_job.package_id).get_node("%DeliveryControl") as Control).visible, "private promise has no terminal delivery controls")
	_check(not "Доставка:" in _description(panel) and not "ui_private_trap" in _description(panel), "private agreement and trap not disclosed")
	var first: NpcHomeDelivery = terminal_jobs[0]
	var second: NpcHomeDelivery = terminal_jobs[1]
	var first_record: PackageRegistrationRecord = PackageHistoryService.record_for(first.package_id)
	var second_record: PackageRegistrationRecord = PackageHistoryService.record_for(second.package_id)
	if not restoring:
		_check((_line(panel, first.package_id).get_node("%TextureAlertIconInfo") as Control).visible, "unselected offer remains unread")
		panel._on_package_selected(first.package_id)
		_check(not first_record.read_event_ids.is_empty(), "opening details marks real event read")
		var accept_button: Button = _line(panel, first.package_id).get_node("%ButtonDeliveryOK") as Button
		accept_button.grab_focus()
		accept_button.pressed.emit()
		_check(first.status == NpcHomeDelivery.Status.ACCEPTED, "real button accepts one proposal")
		_check(get_viewport().gui_get_focus_owner() == _line(panel, first.package_id).get_node("%Button"), "focus survives action")
		panel._on_package_selected(second.package_id)
		(_line(panel, second.package_id).get_node("%ButtonDeloveryCancel") as Button).pressed.emit()
		_check(second.status == NpcHomeDelivery.Status.DECLINED, "real button declines optional delivery")
		var visit: CustomerVisit = CustomerFlowService.find_visit(second.visit_id)
		_check(CustomerFlowService.create_complaint(visit, 1, CustomerComplaint.Reason.NOT_DELIVERED, true), "known complaint created")
		visit.complaint.message = COMPLAINT_TEXT
		panel._refresh(true)
		_check(COMPLAINT_TEXT in _description(panel), "known complaint rendered")
		panel.close_panel()
		district.definition = load("res://content/definitions/gameplay/npc/def_district_default.tres") as DEF_District
		var data: Dictionary = WorldSnapshotService.capture(level, 1)
		_check(WorldSnapshotService.valid(data, level), "snapshot includes valid read markers and decisions")
		_check(AutosaveStore.write(data, SAVE_PATH) == OK, "dedicated slot written")
	else:
		var first_reads: PackedStringArray = first_record.read_event_ids.duplicate()
		var second_reads: PackedStringArray = second_record.read_event_ids.duplicate()
		_check(not first_reads.is_empty() and not second_reads.is_empty(), "read markers restored from disk")
		panel._on_package_selected(first.package_id)
		_check("Принята" in _description(panel), "accepted status restored in details")
		_check(not (_line(panel, first.package_id).get_node("%ButtonDeliveryOK") as Button).visible, "accepted offer cannot be accepted again")
		panel._on_package_selected(second.package_id)
		_check("Предложение отклонено" in _description(panel) and COMPLAINT_TEXT in _description(panel), "decline and known complaint restored")
		panel._refresh(true)
		panel.close_panel()
		panel.open_for(actor)
		_check(first_record.read_event_ids == first_reads and second_record.read_event_ids == second_reads, "reopen and refresh do not recreate read events")
		_check(not (_line(panel, second.package_id).get_node("%TextureAlertIconWar") as Control).visible, "read complaint does not become unread after restart")
		panel.close_panel()
		_cleanup_slot()
	_check(CustomerFlowService.parcel_for(first.package_id) != null and CustomerFlowService.parcel_for(second.package_id) != null, "decisions preserve physical boxes")
	_check(WalletService.current().operations.size() == 0, "UI decisions do not issue money")
	print("District terminal delivery smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _line(panel: TerminalPanel, package_id: String) -> UI_TerminalButtonPackage:
	for child: Node in panel.get_node("%PackageList").get_children():
		var row: UI_TerminalButtonPackage = child as UI_TerminalButtonPackage
		if row.package_id() == package_id:
			return row
	return null

func _description(panel: TerminalPanel) -> String:
	return (panel.get_node("%PackageDetailInfo").get_node("%RichTextLabelDescription") as RichTextLabel).text

func _cleanup_slot() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Terminal delivery smoke: " + message)
#endregion
