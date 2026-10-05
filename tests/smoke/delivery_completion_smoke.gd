extends Node
## Связная приёмка доставки, ручной потери и ночного сохранения реального района в двух процессах.

const SAVE_PATH: String = "user://delivery_completion_smoke.pvzh"
const MISSING_SLOT: String = "user://delivery_completion_missing/slot.pvzh"
const NOTE_TEXT: String = "Уточнить адрес у получателя. Не помечать потерянной автоматически."
const MAX_RECEIVING_FRAMES: int = 900
const EXPECTED_BATCH_SIZE: int = 5
const SERVICE_TREE: String = "res://content/ai/trees/bt_npc_service.tres"

var _failed: bool = false

#region Полный район и два процесса
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
		level.set_physics_process(false)
		var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(WorldSnapshotService.valid(snapshot, level), "saved morning is valid")
		_check(WorldSnapshotService.restore(snapshot, level), "complete district restored in new process")
		if not _failed:
			_check_restored(level)
		_cleanup_slot()
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE:
				break
		level.set_physics_process(false)
		_check(CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE, "real morning batch arrived")
		if not _failed:
			_prepare_deliveries(level)
	print("Delivery completion smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _prepare_deliveries(level: Node3D) -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	var district: C_District = DistrictPopulationService.current()
	district.definition = district.definition.duplicate() as DEF_District
	district.definition.personal_delivery_probability = 0.0
	district.definition.delivery_bargain_probability = 1.0
	district.definition.terminal_delivery_minimum = 3
	district.definition.terminal_delivery_maximum = 3
	district.delivery_offer_day = 0
	district.terminal_offer_target = 0
	district.delivery_considered.clear()
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	var unregistered: CustomerVisit = flow.visits.back()
	for visit: CustomerVisit in flow.visits:
		var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
		if person != null and not person.profile.resident:
			unregistered = visit
			break
	for visit: CustomerVisit in flow.visits:
		if visit != unregistered:
			_check(PackageRegistrationService.register_package(CustomerFlowService.parcel_for(visit.package_id)).outcome == PackageScanResult.Outcome.REGISTERED, "real parcel registered")
	_check(district.home_deliveries.size() >= 3, "three actual local delivery offers available")
	if district.home_deliveries.size() < 3:
		return

	var delivered: NpcHomeDelivery = district.home_deliveries[0]
	var refused: NpcHomeDelivery = district.home_deliveries[1]
	var missed: NpcHomeDelivery = district.home_deliveries[2]
	_check(NpcDeliveryOfferService.negotiate(delivered.job_id) == NpcHomeDelivery.Bargain.ACCEPTED, "private bonus negotiated once")
	for job: NpcHomeDelivery in [delivered, refused, missed]:
		_check(NpcDeliveryOfferService.accept(job.job_id), "real delivery accepted")
	var player: Entity = level.get_node("Entityes/Player") as Entity
	_handoff(delivered, player, false)
	_handoff(refused, player, true)
	_check(delivered.status == NpcHomeDelivery.Status.DELIVERED and delivered.bonus_committed, "success completed and bonus paid")
	_check(refused.status == NpcHomeDelivery.Status.REFUSED and not refused.bonus_committed, "recipient refusal has no bonus")
	_check(WalletService.current().operations.size() == 2, "ordinary payment and bonus use two operations")

	var missing_box: Entity = CustomerFlowService.parcel_for(unregistered.package_id)
	ECS.world.remove_entity(missing_box)
	_check(unregistered.declaration == CustomerVisit.Declaration.NONE, "missing unregistered box is not automatically LOST")
	var panel: TerminalPanel = level.get_node("Entityes/Terminal/TerminalPanel") as TerminalPanel
	panel._selected_package_id = unregistered.package_id
	panel.open_for(player)
	panel._refresh(true)
	var missing_row: UI_TerminalButtonPackage = _row(panel, unregistered.package_id)
	_check(missing_row != null, "missing receipt remains a real terminal row")
	if missing_row == null:
		panel.close_panel()
		return
	(missing_row.get_node("%ButtonLost") as Button).pressed.emit()
	var detail: UI_TerminalPackageDetailInfo = panel.get_node("%PackageDetailInfo") as UI_TerminalPackageDetailInfo
	_check(unregistered.declaration == CustomerVisit.Declaration.LOST, "real terminal action declares unregistered loss")
	_check(PackageHistoryService.record_for(unregistered.package_id).number == 0, "manual loss never assigns pickup number")
	panel._on_package_selected(missed.package_id)
	var editor: TextEdit = detail.get_node("MarginContainer/VBoxContainer/TextEdit") as TextEdit
	editor.insert_text_at_caret(NOTE_TEXT)
	panel.close_panel()
	_check(PackageHistoryService.record_for(missed.package_id).note == NOTE_TEXT, "actual terminal input updates stable history on close")
	_night(level, player, missed)

func _handoff(job: NpcHomeDelivery, player: Entity, decline: bool) -> void:
	var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
	var original: DEF_Customer = visit.definition
	visit.definition = original.duplicate() as DEF_Customer
	visit.definition.private_inspection = false
	visit.definition.voluntary_refusal = decline
	visit.definition.false_complaint_probability = 0.0
	visit.definition.voluntary_complaint_probability = 0.0
	var body: E_DistrictNpc = DistrictPopulationService.body_for(job.npc_id)
	_check(NpcHomeDeliveryService.knock(player, _door(job.address_id)), "persistent recipient called at correct door")
	body.place_at(DistrictPopulationService.position_for(job.address_id))
	(player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	(body.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	_tick(body)
	var parcel: Entity = CustomerFlowService.parcel_for(job.package_id)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), player))
	_check(CustomerFlowService.confirm_direct_delivery(player, body) == PackageDeliveryCheck.Result.READY, "real held box passed ordinary checks")
	_tick(body)
	_check(NpcHomeDeliveryService.meeting_for(body) == null and not body.has_component(C_CustomerAgent), "tree releases completed home encounter")
	_check((CustomerFlowService.parcel_for(job.package_id) != null) == decline, "physical box survives only recipient refusal")
	visit.definition = original

func _night(level: Node3D, player: Entity, missed: NpcHomeDelivery) -> void:
	var district: C_District = DistrictPopulationService.current()
	district.definition = load("res://content/definitions/gameplay/npc/def_district_default.tres") as DEF_District
	var parcel: Entity = CustomerFlowService.parcel_for(missed.package_id)
	var pose: Transform3D = (parcel as Node as Node3D).global_transform
	(player as Node as Node3D).global_position = (level.get_node("Entityes/SleepPoint") as Node3D).global_position
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.SLEEP
	request.expected_day = 1
	request.expected_phase = C_DayCycle.Phase.EVENING
	_check(DayPhaseService.submit(request), "normal sleep request accepted")
	if DayPhaseService.current().pending_transition == null:
		return
	var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one()
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = MISSING_SLOT
	ECS.world.process(0.1, "GamePlay")
	_check(DayPhaseService.current().phase == C_DayCycle.Phase.NIGHT and not DayPhaseService.current().night_ready, "failed real write holds night")
	_check(state.started_night == 1 and missed.status == NpcHomeDelivery.Status.FAILED, "evening prepared once despite write failure")
	var operation_count: int = WalletService.current().operations.size()
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	ECS.world.process(0.1, "GamePlay")
	_check(state.last_error == OK and DayPhaseService.current().night_ready, "retry writes the same prepared morning")
	_check(WalletService.current().operations.size() == operation_count, "retry creates no duplicate payment or fine")
	_check((parcel as Node as Node3D).global_transform == pose, "sleep leaves real missed box at original position")
	_check(WorldSnapshotService.valid(AutosaveStore.read(SAVE_PATH), level), "written morning is coherent")
#endregion

#region Проверка после перезапуска
func _check_restored(level: Node3D) -> void:
	var district: C_District = DistrictPopulationService.current()
	_check(DayPhaseService.current().day_index == 2 and DayPhaseService.current().phase == C_DayCycle.Phase.MORNING, "new process restores next morning")
	var finished_count: int = 0
	var refused_count: int = 0
	var missed_count: int = 0
	for job: NpcHomeDelivery in district.home_deliveries:
		var visit: CustomerVisit = CustomerFlowService.find_visit(job.visit_id)
		if job.status == NpcHomeDelivery.Status.DELIVERED:
			finished_count += 1
			_check(job.bonus_committed and visit.settlement_committed and CustomerFlowService.parcel_for(job.package_id) == null, "success restores without recreating delivered box")
			_check(NpcHomeDeliveryService.complete(job), "completed success is idempotent")
		elif job.status == NpcHomeDelivery.Status.REFUSED:
			refused_count += 1
			_check(_box_count(job.package_id) == 1 and not job.bonus_committed, "refusal restores one physical box and no bonus")
			_check(NpcHomeDeliveryService.complete(job), "completed refusal is idempotent")
		elif job.status == NpcHomeDelivery.Status.FAILED:
			missed_count += 1
			_check(_box_count(job.package_id) == 1 and visit.declaration == CustomerVisit.Declaration.NONE and visit.actual == CustomerVisit.Actual.NOT_RESOLVED, "missed promise restores one unresolved real box")
			_check(CustomerFlowService.visit_due(visit, 2) and CustomerFlowService.arrival_allowed(visit), "next day permits ordinary collection without bonus")
			_check(PackageHistoryService.record_for(job.package_id).note == NOTE_TEXT, "stable note survives actual restart")
	_check(finished_count == 1 and refused_count == 1 and missed_count == 1, "three distinct final delivery outcomes restored")
	var lost_count: int = 0
	for visit: CustomerVisit in CustomerFlowService.current().visits:
		if visit.declaration == CustomerVisit.Declaration.LOST:
			lost_count += 1
			_check(visit.finished and PackageHistoryService.record_for(visit.package_id).number == 0, "manual unregistered loss remains closed without pickup number")
	_check(lost_count == 1, "only explicitly declared case is LOST")
	var wallet: C_Wallet = WalletService.current()
	var operation_count: int = wallet.operations.size()
	_check(NpcHomeDeliveryService.finish_evening(1) and NpcHomeDeliveryService.finish_evening(1), "repeated evening processing is stable")
	_check(wallet.operations.size() == operation_count, "restart and retry never duplicate money")
	var panel: TerminalPanel = level.get_node("Entityes/Terminal/TerminalPanel") as TerminalPanel
	panel._refresh(true)
#endregion

#region Ограниченные helpers
func _row(panel: TerminalPanel, package_id: String) -> UI_TerminalButtonPackage:
	for child: Node in panel.get_node("%PackageList").get_children():
		var row: UI_TerminalButtonPackage = child as UI_TerminalButtonPackage
		if row != null and row.package_id() == package_id:
			return row
	return null

func _tick(body: E_DistrictNpc) -> void:
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	if runner.behavior_tree.resource_path != SERVICE_TREE:
		runner.behavior_tree = load(SERVICE_TREE) as BehaviorTree
	(body.get_component(C_NpcDecision) as C_NpcDecision).intent_owner = C_NpcDecision.Owner.NONE
	_check(NpcBrainService.update_tree(body, 0.2), "native home service tree selected action")

func _door(address_id: StringName) -> Entity:
	for door: Entity in ECS.world.query.with_all([C_NpcAddress]).execute():
		if (door.get_component(C_NpcAddress) as C_NpcAddress).address_id == address_id:
			return door
	return null

func _box_count(package_id: String) -> int:
	var count: int = 0
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		if (parcel.get_component(C_Package) as C_Package).package_id == package_id:
			count += 1
	return count

func _cleanup_slot() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Delivery completion smoke: " + message)
#endregion
