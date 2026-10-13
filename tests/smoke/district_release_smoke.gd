extends Node
## Связная приёмка района: два дня, native Systems и новый процесс восстановления.

const SAVE_PATH: String = "user://district_release_smoke.pvzh"
const LEVEL_PATH: String = "res://content/scenes/main_level.tscn"
const DISTRICT_PATH: String = "res://content/domains/npc/definitions/def_district_default.tres"
const FOOD_PATH: String = "res://content/domains/inventory/entities/food_pickup.tscn"
const SHELF_PATH: String = "res://content/domains/inventory/definitions/def_item_large_shelf.tres"
const RAW_PATH: NodePath = ^"Entityes/Props/Barrel_A_rigid"
const NAVIGATION_CHECKS: Script = preload("res://utils/warehouse_navigation_checks.gd")
const NOTE_TEXT: String = "Обещанная доставка: проверить у дома, не объявлять потерю автоматически."
const BATCH_SIZE: int = 5
const MAX_RECEIVING_FRAMES: int = 1800
const MAX_SERVICE_FRAMES: int = 18000
const MAX_TRANSITION_FRAMES: int = 1200
const MAX_ENCOUNTER_FRAMES: int = 3600
const UNLOAD_DISTANCE: float = 12.0
const READY_RADIUS: float = 6.0
const INITIAL_BALANCE: int = 1000
const LIGHT_TIMEOUT_REASON: String = "Свет не выключили"
# Проверяем авторский регулируемый timeout до вмешательства соседних опасных NPC.
const SMOKE_LIGHT_WAIT_SECONDS: float = 5.0
# Peaceful outdoor exposure: above dark-hunt threshold, below light aversion.
# The authored service light still forces the real light-warning/timeout branch.
const SMOKE_AMBIENT_LIGHT: float = 0.3

var _failed: bool = false
var _scenario_completed: bool = false
var _restore_graph_checks: int = 0
var _result_checks: int = 0
var _post_operation_checks: int = 0
var _observed_light_waits: Dictionary[StringName, int] = { }
var _staged_light_visits: Dictionary[StringName, int] = { }
var _level: Node3D
var _player: Entity
var _zone: E_ReceivingZone
var _cycle: C_DayCycle
var _flow: C_CustomerFlow
var _receiving: C_Receiving
var _panel: TerminalPanel
var _day_one_jobs: Array[StringName] = []


#region Реальный уровень и отдельный процесс
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup_slot()
	_level = (load(LEVEL_PATH) as PackedScene).instantiate() as Node3D
	_level.set("autosave_path", SAVE_PATH)
	add_child(_level)
	_bind_level()
	# Физические предметы и NPC продолжают native обработку. Только ввод/ходьба
	# тестового игрока заменены явными действиями fixture.
	(_player as Node).set_physics_process(false)
	if restoring:
		await _restore_acceptance()
	else:
		await _connected_days()
	_check(_scenario_completed, "scenario reached its full acceptance boundary")
	_level.free()
	ECS.world = null
	if restoring:
		_cleanup_slot()
	print(
		"District release smoke ",
		"restore" if restoring else "write",
		": ",
		"FAIL" if _failed else "PASS",
	)
	get_tree().quit(1 if _failed else 0)


func _bind_level() -> void:
	_player = _level.get_node("Entityes/Player") as Entity
	_zone = _level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	_receiving = _zone.get_component(C_Receiving) as C_Receiving
	_panel = _level.get_node("Entityes/Terminal/TerminalPanel") as TerminalPanel
	_cycle = DayPhaseQueries.current()
	_flow = CustomerFlowQueries.current()


func _connected_days() -> void:
	var navigation_errors: Array[String] = await NAVIGATION_CHECKS.failures(
		_level,
		_level.get_node("WarehouseNavigation") as NavigationRegion3D,
	)
	_check(navigation_errors.is_empty(), "native navigation: " + "; ".join(navigation_errors))
	_check(_cycle.day_index == 1, "new district starts on day one")
	WalletService.current().balance = INITIAL_BALANCE
	# Детерминированный выбор трёх настоящих предложений; shared .tres не меняется.
	var district: C_District = NpcPopulationQueries.current()
	district.definition = district.definition.duplicate() as DEF_District
	district.definition.personal_delivery_probability = 0.0
	district.definition.personal_delivery_daily_minimum = 0
	district.definition.terminal_delivery_minimum = 3
	district.definition.terminal_delivery_maximum = 3
	district.delivery_offer_day = 0
	await _unload(1)
	if _failed:
		return
	_prepare_terminal()
	if _failed:
		return
	_load_sale_and_raw()
	await _transition(DayTransitionRequest.Kind.START_SHIFT, C_DayCycle.Phase.DAY, 1)
	_verify_cargo(2)
	var operations: int = WalletService.current().operations.size()
	var balance: int = WalletService.current().balance
	_check(TruckCargoService.commit(_zone, _cycle), "repeated dispatched cargo is acknowledged")
	_check(
		WalletService.current().operations.size() == operations
		and WalletService.current().balance == balance,
		"repeated START cargo does not repay",
	)
	await _buy_furniture()
	await _serve_counter(1, false)
	await _transition(DayTransitionRequest.Kind.FINISH_SHIFT, C_DayCycle.Phase.EVENING, 1)
	if _failed:
		return
	district.definition.ambient_light = SMOKE_AMBIENT_LIGHT
	await _home_handoff(_day_one_jobs[0], false)
	await _home_handoff(_day_one_jobs[1], true)
	_check(
		HomeDeliveryQueries.find(_day_one_jobs[2]).status == NpcHomeDelivery.Status.ACCEPTED,
		"third genuine promise remains unresolved before sleep",
	)
	district.definition = load(DISTRICT_PATH) as DEF_District
	await _sleep_until(2)
	if _failed:
		return
	_check_day_one_history()
	district.definition = district.definition.duplicate() as DEF_District
	district.definition.service_wait_timeout = SMOKE_LIGHT_WAIT_SECONDS
	district.definition.ambient_light = SMOKE_AMBIENT_LIGHT
	await _unload(2)
	await _wait_furniture()
	_load_refused_return()
	_register_incoming()
	_check_service_light()
	await _wait_prepared_queue()
	await _transition(DayTransitionRequest.Kind.START_SHIFT, C_DayCycle.Phase.DAY, 2)
	_verify_cargo(3)
	await _serve_counter(2, true)
	if _failed:
		return
	await _transition(DayTransitionRequest.Kind.FINISH_SHIFT, C_DayCycle.Phase.EVENING, 2)
	district.definition = load(DISTRICT_PATH) as DEF_District
	await _sleep_until(3)
	if _failed:
		return
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(
		WorldSnapshotService.can_restore(snapshot, _level),
		"second Night writes coherent Morning3",
	)
	_check_results()
	_result_checks += 1
	_scenario_completed = not _failed and _result_checks == 1
	print("Connected district: actual shifts 1/2, Nights 1/2, Morning3 saved")


func _restore_acceptance() -> void:
	_check(
		_cycle.day_index == 3 and _cycle.phase == C_DayCycle.Phase.MORNING,
		"native startup restores Morning3 in a fresh process",
	)
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(
		WorldSnapshotService.can_restore(snapshot, _level),
		"restart snapshot passes full preflight",
	)
	_check_saved_domains(snapshot)
	_check_results()
	_restore_graph_checks += 1
	_result_checks += 1
	if _failed:
		return
	# Повторный reload проверяется в quiescent fixture; другого gameplay clock нет.
	_level.set_physics_process(false)
	var balance: int = WalletService.current().balance
	var operations: int = WalletService.current().operations.size()
	for _attempt: int in 2:
		_check(WorldSnapshotService.restore(snapshot, _level), "same complete snapshot reloads")
		_bind_level()
		_check_saved_domains(snapshot)
		_check_results()
		_restore_graph_checks += 1
		_result_checks += 1
		_check(
			WalletService.current().balance == balance
			and WalletService.current().operations.size() == operations,
			"reload preserves one ledger without repayment",
		)
		var commerce: C_Commerce = CommerceService.current()
		var delivery_zone: Entity = _level.get_node("Entityes/OrderReceiving") as Entity
		var state: C_OrderReceiving = (
			delivery_zone.get_component(C_OrderReceiving) as C_OrderReceiving
		)
		_check(
			not OrderDeliveryService.fulfill_one(delivery_zone, state, commerce, 3),
			"issued furniture never spawns twice",
		)
		for job: NpcHomeDelivery in NpcPopulationQueries.current().home_deliveries:
			if job.day_index == 1 and job.status == NpcHomeDelivery.Status.DELIVERED:
				_check(
					NpcHomeDeliveryService.complete(job),
					"completed home delivery is idempotent",
				)
		_check(NpcHomeDeliveryService.finish_evening(1), "closed evening is idempotent")
		_check(
			WalletService.current().balance == balance
			and WalletService.current().operations.size() == operations,
			"repeated fulfillment and delivery never repay",
		)
		# Сверка до следующего restore ловит также нефинансовые повторные последствия.
		_check_saved_domains(snapshot)
		_check_results()
		_post_operation_checks += 1
	_scenario_completed = (
		not _failed and _restore_graph_checks == 3 and _result_checks == 3
		and _post_operation_checks == 2
	)
#endregion


#region Поступление, терминал и truck transaction
func _unload(day_index: int) -> void:
	var blocked_before: bool = false
	for _frame: int in MAX_RECEIVING_FRAMES:
		await get_tree().physics_frame
		if not DayPhaseService.start_blockers(_cycle).is_empty():
			blocked_before = true
		var truck: E_MorningTruck = _zone.get_truck()
		if truck == null:
			continue
		for index: int in _receiving.incoming_package_ids.size():
			var parcel: Entity = PackageQueries.find_live_package(
				_receiving.incoming_package_ids[index],
			)
			if parcel == null:
				continue
			var body: RigidBody3D = parcel as Node as RigidBody3D
			var marker: Node3D = _zone.get_spawn_points().get_child(index) as Node3D
			# Fixture разгрузки задаёт физическую позу; gate измеряет настоящий объём.
			body.freeze = true
			body.global_transform = marker.global_transform
			body.global_position += truck.global_basis.x * UNLOAD_DISTANCE
		if (
			_receiving.last_started_day == day_index
			and _receiving.incoming_package_ids.size() == BATCH_SIZE
			and _receiving.pending.is_empty()
		):
			break
	_check(blocked_before, "shift gate blocks unfinished physical unloading")
	_check(
		_receiving.last_started_day == day_index
		and _receiving.incoming_package_ids.size() == BATCH_SIZE and _receiving.pending.is_empty(),
		"native receiving unloads five real parcels on day %d" % day_index,
	)
	await get_tree().physics_frame
	_check(DayPhaseService.start_blockers(_cycle).is_empty(), "unloaded truck permits shift")


func _prepare_terminal() -> void:
	var missing_visit: CustomerVisit = null
	for visit: CustomerVisit in _flow.visits:
		var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
		if person.profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
			missing_visit = visit
			break
	_check(
		missing_visit != null,
		"actual fire recipient's incoming parcel selected for manual LOST",
	)
	if missing_visit == null:
		return
	ECS.world.remove_entity(PackageQueries.find_live_package(missing_visit.package_id))
	_check(
		missing_visit.declaration == CustomerVisit.Declaration.NONE,
		"physical disappearance never declares LOST automatically",
	)
	_panel.open_for(_player)
	_panel.call("_refresh", true)
	var row: UI_TerminalButtonPackage = _row(missing_visit.package_id)
	_check(row != null, "unregistered missing receipt stays visible in terminal")
	if row == null:
		_panel.close_panel()
		return
	(row.get_node("%ButtonLost") as Button).pressed.emit()
	var operations: int = WalletService.current().operations.size()
	var balance: int = WalletService.current().balance
	_panel.call("_on_lost_requested", missing_visit.package_id)
	_check(
		missing_visit.declaration == CustomerVisit.Declaration.LOST
		and PackageHistoryService.record_for(missing_visit.package_id).number == 0,
		"real terminal declares loss without pickup number",
	)
	_check(
		WalletService.current().operations.size() == operations
		and WalletService.current().balance == balance,
		"repeated manual loss never settles twice",
	)
	_panel.close_panel()
	_register_incoming()
	var offers: Array[NpcHomeDelivery] = HomeDeliveryQueries.terminal_offers()
	_check(offers.size() == 3, "three published offers for real registered residents")
	if offers.size() != 3:
		return
	for job: NpcHomeDelivery in offers:
		_day_one_jobs.append(job.job_id)
		_panel.open_for(_player)
		_panel.call("_refresh", true)
		row = _row(job.package_id)
		_check(row != null, "actual published delivery row exists")
		if row == null:
			_panel.close_panel()
			return
		var accept_button: Button = row.get_node("%ButtonDeliveryOK") as Button
		_check(not accept_button.disabled, "published delivery action enabled")
		accept_button.pressed.emit()
		_check(job.status == NpcHomeDelivery.Status.ACCEPTED, "terminal accepts genuine promise")
		_panel.close_panel()
	_panel.open_for(_player)
	_panel.call("_on_package_selected", offers[2].package_id)
	var detail: UI_TerminalPackageDetailInfo = (
		_panel.get_node("%PackageDetailInfo") as UI_TerminalPackageDetailInfo
	)
	var editor: TextEdit = detail.get_node("MarginContainer/VBoxContainer/TextEdit") as TextEdit
	editor.insert_text_at_caret(NOTE_TEXT)
	_panel.close_panel()
	_check(
		PackageHistoryService.record_for(offers[2].package_id).note == NOTE_TEXT,
		"real note editor updates persistent history",
	)


func _register_incoming() -> void:
	for package_id: String in _receiving.incoming_package_ids:
		var parcel: Entity = PackageQueries.find_live_package(package_id)
		if parcel != null:
			var visit: CustomerVisit = CustomerFlowQueries.find_visit(
				StringName("visit/" + package_id),
			)
			var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
			# Player input leaves the fire order unscanned; its aura and native AI stay active.
			# Fire opening/damage has separate regressions; this fixture exercises ordinary service.
			if person.profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) != null:
				continue
			_check(
				PackageRegistrationService.register_package(parcel).outcome
				== PackageScanResult.Outcome.REGISTERED,
				"real shipment registered through scanner contract",
			)


func _load_sale_and_raw() -> void:
	var truck: E_MorningTruck = _zone.get_truck()
	var sale: Entity = (load(FOOD_PATH) as PackedScene).instantiate() as Entity
	_level.add_child(sale)
	EntityCompositionFixture.register(ECS.world, sale, false)
	(sale as Node as RigidBody3D).freeze = true
	(sale as Node as Node3D).global_transform = truck.cargo_slots[0].global_transform
	var raw: RigidBody3D = _level.get_node(RAW_PATH) as RigidBody3D
	raw.gravity_scale = 0.0
	raw.global_transform = truck.cargo_slots[1].global_transform
	_check(
		PhysicsGrabTarget.handle_for(raw, true) != null,
		"native raw actor creates transient proxy",
	)
	_check(_receiving.cargo_receipts.is_empty(), "cargo presence alone never commits sale")


func _load_refused_return() -> void:
	var job: NpcHomeDelivery = HomeDeliveryQueries.find(_day_one_jobs[1])
	var parcel: Entity = PackageQueries.find_live_package(job.package_id)
	_check(
		PackageReturnService.can_return(parcel),
		"actual recipient refusal permits morning return",
	)
	if parcel == null:
		return
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.freeze = true
	body.global_transform = _zone.get_truck().cargo_slots[0].global_transform
	_check(
		CustomerFlowQueries.find_visit(job.visit_id).disposition
		== CustomerVisit.Disposition.WAREHOUSE,
		"loading return leaves warehouse ownership until shift",
	)


func _verify_cargo(expected: int) -> void:
	_check(_receiving.cargo_receipts.size() == expected, "cargo commits one receipt per real actor")
	for receipt: TruckCargoReceipt in _receiving.cargo_receipts:
		_check(receipt.removed and receipt.settled, "removed cargo reaches terminal settlement")
	_check(
		_level.get_node_or_null(RAW_PATH) == null,
		"authored raw disposal survives Night and reload",
	)
#endregion


#region Мебель и реальные клиентские исходы
func _buy_furniture() -> void:
	var merchant: E_DistrictNpc = NpcActivityService.merchant()
	var shop: CommercePanel = CommercePanelFactory.open(_player, merchant)
	_check(shop != null, "actual merchant opens in active shift")
	if shop == null:
		return
	var shelf: DEF_InventoryItem = load(SHELF_PATH) as DEF_InventoryItem
	shop.call("_buy", shelf)
	var purchase_dialog: ConfirmationDialog = shop.get("_purchase_dialog") as ConfirmationDialog
	purchase_dialog.custom_action.emit(&"delivery")
	shop.close_panel()
	await get_tree().process_frame
	var commerce: C_Commerce = CommerceService.current()
	_check(
		commerce.pending_deliveries.size() == 1 and commerce.receipts.size() == 1,
		"actual delivery popup commits one furniture purchase",
	)
	if commerce.pending_deliveries.size() == 1:
		_check(
			commerce.pending_deliveries[0].delivery_day == 2
			and not commerce.pending_deliveries[0].fulfilled,
			"large furniture waits for next morning",
		)


func _wait_furniture() -> void:
	for _frame: int in MAX_TRANSITION_FRAMES:
		await get_tree().physics_frame
		if CommerceService.current().pending_deliveries[0].fulfilled:
			break
	var order: PendingDelivery = CommerceService.current().pending_deliveries[0]
	_check(order.fulfilled, "native order System fulfills next-morning furniture")
	_check(
		_goods_count(OrderDeliveryService.key_for(order)) == 1,
		"one physical shelf materialized",
	)
	var goods: Entity = _goods(OrderDeliveryService.key_for(order))
	if goods != null:
		_check(
			(goods as Node as RigidBody3D).mass == 75.0 and goods.has_component(C_Grabbable)
			and not goods.has_component(C_PlayerAnchored),
			"delivered shelf remains massive and movable",
		)


func _home_handoff(job_id: StringName, refusal: bool) -> void:
	var job: NpcHomeDelivery = HomeDeliveryQueries.find(job_id)
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	var home_position: Vector3 = NpcPopulationQueries.position_for(job.address_id)
	var safe_home: bool = false
	for _frame: int in MAX_ENCOUNTER_FRAMES:
		safe_home = NpcRouteSolver.refuge_is_safe(body, home_position)
		if safe_home:
			break
		await get_tree().physics_frame
	_check(safe_home, "moving native hazards clear the actual home handoff location")
	if _failed:
		return
	_check(
		NpcHomeDeliveryService.knock(_player, _door(job.address_id)),
		"correct home door binds meeting",
	)
	if _failed:
		return
	# Home path/visual acceptance belongs to owner QA; native BT still owns the encounter.
	body.place_at(home_position)
	(body.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	(_player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	NpcDecisionService.request_wake(body, &"smoke/home", true)
	for _frame: int in MAX_TRANSITION_FRAMES:
		await get_tree().physics_frame
		var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
		if agent != null and agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
			break
	await _give_box(body, CustomerFlowQueries.find_visit(job.visit_id), refusal)
	for _frame: int in MAX_TRANSITION_FRAMES:
		await get_tree().physics_frame
		if job.status != NpcHomeDelivery.Status.ACCEPTED:
			break
	_check(
		job.status
		== (NpcHomeDelivery.Status.REFUSED if refusal else NpcHomeDelivery.Status.DELIVERED),
		"native home BT completes requested actual outcome",
	)
	_check(job.bonus_committed == not refusal, "only successful home delivery earns bonus")
	_check(HomeMeetingQueries.meeting_for(body) == null, "completed meeting releases relationship")
	if refusal:
		_panel.open_for(_player)
		_panel.call("_refresh", true)
		var row: UI_TerminalButtonPackage = _row(job.package_id)
		_check(row != null, "actual refusal remains available for terminal reporting")
		if row != null:
			(row.get_node("%ButtonCancel") as Button).pressed.emit()
		_panel.close_panel()
		_check(
			CustomerFlowQueries.find_visit(job.visit_id).declaration
			== CustomerVisit.Declaration.REFUSED,
			"player reports actual recipient refusal before morning return",
		)


func _give_box(
	body: E_DistrictNpc,
	visit: CustomerVisit,
	refusal: bool = false,
	watch_light: bool = false,
) -> void:
	_check(GrabQueries.holder_available(_player), "handoff player remains alive and controllable")
	if _failed:
		return
	var original: DEF_Customer = visit.definition
	visit.definition = original.duplicate() as DEF_Customer
	visit.definition.private_inspection = false
	visit.definition.voluntary_refusal = refusal
	visit.definition.inspection_keep_probability = 1.0
	visit.definition.false_complaint_probability = 0.0
	visit.definition.voluntary_complaint_probability = 0.0
	(_player as Node as Node3D).global_position = body.global_position + Vector3.FORWARD
	NpcDialogueService.close_for(body)
	CustomerFlowService.greet(body)
	var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
	_check(parcel != null, "handoff requires live assigned parcel")
	if parcel != null:
		(parcel as Node as RigidBody3D).freeze = false
		# Fixture supplies held-box input; the domain owns release/check/outcome/removal.
		parcel.add_relationship(Relationship.new(R_HeldBy.new(), _player))
		_check(
			CustomerFlowService.confirm_direct_delivery(_player, body)
			== PackageDeliveryCheck.Result.READY,
			"actual handoff passes ordinary parcel checks",
		)
	# READY may start an archetype-forced inspection. Withdraw while the native BT completes it;
	# standing at the counter throughout inspection exposes the fixture player to nearby attackers.
	if visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
		(_player as Node as Node3D).global_position = (
			_level.get_node("Entityes/SleepPoint") as Node3D
		).global_position
	for _frame: int in MAX_ENCOUNTER_FRAMES:
		if watch_light:
			_stage_light_recipients()
			_observe_light_waits(_cycle.day_index)
		if _failed or visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
			break
		await get_tree().physics_frame
	_check(
		visit.actual
		== (CustomerVisit.Actual.CUSTOMER_REFUSED if refusal else CustomerVisit.Actual.DELIVERED),
		"actual handoff completes before terminal declaration",
	)
	visit.definition = original


func _serve_counter(day_index: int, require_light_timeout: bool) -> void:
	var arrived: int = 0
	var light_deferred: bool = false
	for _frame: int in MAX_SERVICE_FRAMES:
		await get_tree().physics_frame
		if require_light_timeout:
			_stage_light_recipients()
		_observe_light_waits(day_index)
		for candidate: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
			var body: E_DistrictNpc = candidate as E_DistrictNpc
			var agent: C_CustomerAgent = candidate.get_component(C_CustomerAgent) as C_CustomerAgent
			var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
			if (
				body == null or candidate.has_component(C_Death)
				or HomeMeetingQueries.meeting_for(body) != null
				or agent.phase
				not in [
					C_CustomerAgent.Phase.WAITING,
					C_CustomerAgent.Phase.WAITING_FOR_PACKAGE,
					C_CustomerAgent.Phase.DIALOGUE,
				]
				or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			):
				continue
			arrived += 1
			print("Actual counter arrival day=", day_index, " npc=", visit.customer_id)
			await _give_box(body, visit, false, require_light_timeout)
			if _failed:
				return
			_panel.open_for(_player)
			_panel.call("_refresh", true)
			var row: UI_TerminalButtonPackage = _row(visit.package_id)
			_check(row != null, "issued parcel has real terminal settlement action")
			if row != null:
				(row.get_node("%ButtonOK") as Button).pressed.emit()
			_panel.close_panel()
		for visit: CustomerVisit in _flow.visits:
			if _is_observed_light_timeout(visit, day_index):
				light_deferred = true
				_check(
					visit.actual == CustomerVisit.Actual.NOT_RESOLVED
					and visit.declaration == CustomerVisit.Declaration.NONE
					and not visit.settlement_committed and visit.money_delta == 0
					and visit.disposition == CustomerVisit.Disposition.WAREHOUSE,
					"light timeout retains real unresolved order without false LOST/payment",
				)
				var unavailable: CustomerVisit = visit.duplicate() as CustomerVisit
				unavailable.defer_reason = "Получатель недоступен"
				_check(
					not _is_observed_light_timeout(unavailable, day_index),
					"same warned recipient deferred for another reason is not a light timeout",
				)
				var another_day: CustomerVisit = visit.duplicate() as CustomerVisit
				another_day.deferred_day = day_index + 1
				_check(
					not _is_observed_light_timeout(another_day, day_index + 1),
					"previous day's warned wait cannot prove a later light timeout",
				)
		if CustomerFlowQueries.actionable_remaining(_flow, day_index) == 0:
			break
		if _failed:
			return
	_check(arrived >= 2 or not require_light_timeout, "available recipients reach native counter")
	if require_light_timeout and not light_deferred:
		for visit: CustomerVisit in _flow.visits:
			if visit.deferred_day == day_index:
				print(
					"Observed deferral npc=", visit.customer_id, " reason=", visit.defer_reason,
					" warned_light_wait=",
					_observed_light_waits.get(visit.visit_id, 0) == day_index,
				)
	_check(light_deferred or not require_light_timeout, "second-day light wait ends explicitly")
	_check(
		DayPhaseService.finish_blockers(_cycle).is_empty(),
		"actual customers permit FINISH_SHIFT: "
		+ "; ".join(DayPhaseService.finish_blockers(_cycle)),
	)
#endregion


#region Авторские очередь/свет и календарь
func _stage_light_recipients() -> void:
	var definition: DEF_District = NpcPopulationQueries.current().definition
	var routes: NpcServiceRoutes = (
		_level.get_node(definition.service_routes_path) as NpcServiceRoutes
	)
	for candidate: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var agent: C_CustomerAgent = candidate.get_component(C_CustomerAgent) as C_CustomerAgent
		if (
			agent.phase != C_CustomerAgent.Phase.QUEUED
			or _staged_light_visits.get(agent.visit_id, 0) == _cycle.day_index
		):
			continue
		var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
		var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
		if person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION) == null:
			continue
		var body: E_DistrictNpc = candidate as E_DistrictNpc
		var start: Node3D = routes.point_for(1, 0)
		# Один раз задаём начальную физическую позицию фактически созданного визита.
		# Очередь, подход, предупреждение и timeout выполняются обычными BT/Systems.
		body.place_at(start.global_position)
		_staged_light_visits[visit.visit_id] = _cycle.day_index
		print("Staged actual light recipient day=", _cycle.day_index, " npc=", visit.customer_id)


func _wait_prepared_queue() -> void:
	for _frame: int in MAX_SERVICE_FRAMES:
		await get_tree().physics_frame
		_observe_light_waits(_cycle.day_index)
		if _nearby_recipients() >= 3:
			break
	_check(_nearby_recipients() >= 3, "second morning prepares current and two nearby recipients")


func _observe_light_waits(day_index: int) -> void:
	for candidate: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var agent: C_CustomerAgent = candidate.get_component(C_CustomerAgent) as C_CustomerAgent
		if (
			agent.phase != C_CustomerAgent.Phase.WAITING_FOR_DARKNESS
			or not agent.light_warning_started
		):
			continue
		var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
		if visit.last_visit_day == day_index:
			if _observed_light_waits.get(visit.visit_id, 0) != day_index:
				print("Actual warned light wait day=", day_index, " npc=", visit.customer_id)
			_observed_light_waits[visit.visit_id] = day_index


func _is_observed_light_timeout(visit: CustomerVisit, day_index: int) -> bool:
	return (
		_observed_light_waits.get(visit.visit_id, 0) == day_index
		and visit.deferred_day == day_index
		and visit.defer_reason == LIGHT_TIMEOUT_REASON
	)


func _nearby_recipients() -> int:
	var count: int = 0
	var station: E_DeliveryCounter = CustomerFlowQueries.counter()
	for person: NpcRecord in NpcPopulationQueries.current().people:
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		if (
			body != null and body.has_component(C_CustomerAgent)
			and body.global_position.distance_to(station.entry_position()) < READY_RADIUS
		):
			count += 1
	return count


func _check_service_light() -> void:
	var definition: DEF_District = NpcPopulationQueries.current().definition
	var zone: NpcLightZone = _level.get_node("LightZones/RoomClient") as NpcLightZone
	var view: CircuitLightView = zone.get_node(zone.flicker_view_path) as CircuitLightView
	var sample: Vector3 = CustomerFlowQueries.counter().waiting_position() + Vector3.UP
	_check(zone.contains_point(sample), "authored volume covers service counter")
	_check(
		LightCircuitService.set_by_id(definition.service_light_circuit, false),
		"native switch off",
	)
	_check(
		NpcLightingService.exposure_at(sample) == definition.ambient_light,
		"switch changes actual authored exposure",
	)
	_check(
		LightCircuitService.set_by_id(definition.service_light_circuit, true),
		"native switch on",
	)
	_check(
		LightCircuitService.flicker(
			definition.service_light_circuit,
			definition.service_flicker_seconds,
			LightFlickerRequest.DEFAULT_INTERVAL_SECONDS,
			&"smoke/release_light",
		),
		"service circuit accepts actual flicker",
	)
	view.call("_process", LightFlickerRequest.DEFAULT_INTERVAL_SECONDS * 1.1)
	_check(
		not zone.is_lit() and zone.is_logically_lit()
		and NpcLightingService.exposure_at(sample, [], null, true) > definition.ambient_light,
		"dark pulse preserves logical light-aversion barrier",
	)
	LightCircuitService.stop_flicker(definition.service_light_circuit, &"smoke/release_light")
	view.call("_process", 0.0)


func _transition(kind: DayTransitionRequest.Kind, phase: C_DayCycle.Phase, day_index: int) -> void:
	if _failed:
		return
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	_check(DayPhaseService.submit(request), "calendar accepts actual transition kind=%d" % kind)
	for _frame: int in MAX_TRANSITION_FRAMES:
		await get_tree().physics_frame
		if _cycle.day_index == day_index and _cycle.phase == phase:
			break
	_check(
		_cycle.day_index == day_index and _cycle.phase == phase,
		"native Systems commit phase=%d day=%d" % [phase, day_index],
	)


func _sleep_until(next_day: int) -> void:
	(_player as Node as Node3D).global_position = (
		_level.get_node("Entityes/SleepPoint") as Node3D
	).global_position
	_check(NpcSleepService.blockers().is_empty(), "normal sleep has no immediate danger")
	await _transition(DayTransitionRequest.Kind.SLEEP, C_DayCycle.Phase.MORNING, next_day)
	var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one()
	var autosave: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	_check(
		autosave.last_error == OK and autosave.last_saved_morning == next_day,
		"actual Night storage commits prepared next morning",
	)
#endregion


#region Durable outcomes and complete graph comparison
func _check_day_one_history() -> void:
	_check(
		HomeDeliveryQueries.find(_day_one_jobs[0]).status == NpcHomeDelivery.Status.DELIVERED
		and HomeDeliveryQueries.find(_day_one_jobs[1]).status == NpcHomeDelivery.Status.REFUSED
		and HomeDeliveryQueries.find(_day_one_jobs[2]).status == NpcHomeDelivery.Status.FAILED,
		"Night retains success/refusal/failed promise without invented delivery",
	)


func _check_results() -> void:
	_verify_cargo(3)
	var kinds: Array[int] = [0, 0, 0]
	for receipt: TruckCargoReceipt in _receiving.cargo_receipts:
		kinds[receipt.kind] += 1
	_check(kinds == [1, 1, 1], "one actual RETURN/SALE/raw DISPOSAL remains")
	var completed: int = 0
	var refused: int = 0
	var missed: int = 0
	for job: NpcHomeDelivery in NpcPopulationQueries.current().home_deliveries:
		if job.day_index != 1:
			continue
		if job.status == NpcHomeDelivery.Status.DELIVERED:
			completed += 1
			_check(job.bonus_committed, "success retains committed bonus")
			_check(
				PackageQueries.find_live_package(job.package_id) == null,
				"delivered box stays gone",
			)
		elif job.status == NpcHomeDelivery.Status.REFUSED:
			refused += 1
			_check(not job.bonus_committed, "refusal earns no home bonus")
			_check(
				CustomerFlowQueries.find_visit(job.visit_id).disposition
				== CustomerVisit.Disposition.RETURNED,
				"refused parcel keeps actual subsequent truck return",
			)
		elif job.status == NpcHomeDelivery.Status.FAILED:
			missed += 1
			_check(
				PackageHistoryService.record_for(job.package_id).note == NOTE_TEXT,
				"missed promise retains actual terminal note",
			)
	_check(
		completed == 1 and refused == 1 and missed == 1,
		"three day-one delivery outcomes persist",
	)
	var lost: int = 0
	for visit: CustomerVisit in _flow.visits:
		if visit.declaration == CustomerVisit.Declaration.LOST:
			lost += 1
			_check(
				PackageHistoryService.record_for(visit.package_id).number == 0 and visit.finished,
				"manual unregistered loss remains explicit and closed",
			)
	_check(lost == 1, "only the player's single manual declaration is LOST")
	_check_unscanned_fire_order()
	var commerce: C_Commerce = CommerceService.current()
	_check(
		commerce.pending_deliveries.size() == 1 and commerce.receipts.size() == 1,
		"one furniture order and payment persist",
	)
	if commerce.pending_deliveries.size() == 1:
		var order: PendingDelivery = commerce.pending_deliveries[0]
		_check(
			order.fulfilled and _goods_count(OrderDeliveryService.key_for(order)) == 1,
			"one fulfilled physical furniture identity persists",
		)
	_check(NpcPopulationQueries.current().people.size() == 12, "no duplicate permanent people")


func _check_unscanned_fire_order() -> void:
	var unscanned: int = 0
	for visit: CustomerVisit in _flow.visits:
		var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
		if (
			visit.arrival_day != 2
			or person.profile.rule_for(DEF_NpcTrait.Kind.FIRE_AURA) == null
		):
			continue
		unscanned += 1
		var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
		var record: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
		_check(
			parcel != null and record != null and record.number == 0
			and visit.actual == CustomerVisit.Actual.NOT_RESOLVED
			and visit.declaration == CustomerVisit.Declaration.NONE
			and not visit.settlement_committed and visit.money_delta == 0
			and visit.disposition == CustomerVisit.Disposition.WAREHOUSE,
			"unscanned fire order survives Night/replay without invented delivery, LOST or payment",
		)
	_check(unscanned == 1, "one real day-two fire order remains unscanned")


func _check_saved_domains(snapshot: Dictionary) -> void:
	var domains: Array[Script] = [
		C_Wallet,
		C_District,
		C_CustomerFlow,
		C_Receiving,
		C_PackageLedger,
		C_LootDrops,
		C_Commerce,
	]
	var saved: Dictionary[String, Dictionary] = { }
	for record: Dictionary in snapshot.entities:
		saved[String(record.key)] = record
	var checked: int = 0
	for owner: Entity in ECS.world.entities:
		var key: String = ActorIdentityRules.key_for(owner, _level)
		for domain: Script in domains:
			if not owner.has_component(domain):
				continue
			_check(saved.has(key), "saved domain owner resolves by stable identity")
			if not saved.has(key):
				continue
			var actual: Dictionary = SaveDataCodec.component_data(owner.get_component(domain))
			_check(
				(saved[key].components as Array).has(actual),
				"full saved aggregate matches after passive restore: " + domain.resource_path,
			)
			checked += 1
	_check(checked == domains.size(), "all seven durable domain aggregates checked")


func _row(package_id: String) -> UI_TerminalButtonPackage:
	for child: Node in _panel.get_node("%PackageList").get_children():
		var row: UI_TerminalButtonPackage = child as UI_TerminalButtonPackage
		if row != null and row.package_id() == package_id:
			return row
	return null


func _door(address_id: StringName) -> Entity:
	for door: Entity in ECS.world.query.with_all([C_NpcAddress]).execute():
		if (door.get_component(C_NpcAddress) as C_NpcAddress).address_id == address_id:
			return door
	return null


func _goods(key: String) -> Entity:
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == key:
			return entity
	return null


func _goods_count(key: String) -> int:
	var count: int = 0
	for entity: Entity in ECS.world.query.with_all([C_PersistentIdentity]).execute():
		if (entity.get_component(C_PersistentIdentity) as C_PersistentIdentity).key == key:
			count += 1
	return count


func _cleanup_slot() -> void:
	for suffix: String in ["", ".tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("District release smoke: " + message)
#endregion
