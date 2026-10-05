extends Node
## Два headless-процесса проверяют реальные предложения и полный снимок района после перезапуска.

const SAVE_PATH: String = "user://district_delivery_offers_smoke.pvzh"
const MAX_RECEIVING_FRAMES: int = 900
const EXPECTED_BATCH_SIZE: int = 5
const TERMINAL_TARGET: int = 3

var _failed: bool = false

#region Снимок реального уровня
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
		_check(not data.is_empty() and WorldSnapshotService.valid(data, level), "stored full world is valid")
		if _failed:
			get_tree().quit(1)
			return
		_check(WorldSnapshotService.restore(data, level), "full world restored")
	else:
		for frame: int in MAX_RECEIVING_FRAMES:
			await get_tree().physics_frame
			if CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE:
				break
	level.set_physics_process(false)
	var district: C_District = DistrictPopulationService.current()
	if not restoring:
		_check(CustomerFlowService.current().visits.size() == EXPECTED_BATCH_SIZE, "real morning batch received")
		district.definition = district.definition.duplicate() as DEF_District
		district.definition.terminal_delivery_minimum = TERMINAL_TARGET
		district.definition.terminal_delivery_maximum = TERMINAL_TARGET
		district.definition.personal_delivery_probability = 0.0
		district.definition.delivery_bargain_probability = 1.0
		district.delivery_offer_day = 0
		district.terminal_offer_target = 0
		district.delivery_considered.clear()
		for visit: CustomerVisit in CustomerFlowService.current().visits:
			var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
			_check(parcel != null, "incoming box exists")
			if parcel != null:
				_check(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED, "real box registered")
		_check(district.home_deliveries.size() >= 3, "several real local delivery offers")
		_check(not NpcDeliveryOfferService.terminal_offers().is_empty(), "published terminal offers exist")
		for index: int in district.home_deliveries.size():
			var job: NpcHomeDelivery = district.home_deliveries[index]
			if job.source == NpcHomeDelivery.Source.PERSONAL:
				_check(NpcDeliveryOfferService.negotiate(job.job_id) == NpcHomeDelivery.Bargain.ACCEPTED, "personal bargain accepted")
			if index == district.home_deliveries.size() - 1:
				_check(NpcDeliveryOfferService.decline(job.job_id), "one offer declined")
			else:
				_check(NpcDeliveryOfferService.accept(job.job_id), "offer accepted")
		district.definition = load("res://content/definitions/gameplay/npc/def_district_default.tres") as DEF_District
		var snapshot: Dictionary = WorldSnapshotService.capture(level, 1)
		_check(WorldSnapshotService.valid(snapshot, level), "captured full world is valid")
		_check_invalid_delivery(snapshot, level)
		_check(AutosaveStore.write(snapshot, SAVE_PATH) == OK, "dedicated test slot written")
	else:
		var before: Array = []
		for job: NpcHomeDelivery in district.home_deliveries:
			before.append([job.job_id, job.package_id, job.visit_id, job.npc_id, job.source, job.status, job.bonus, job.bargain, job.bargain_roll, job.published])
		var considered: PackedStringArray = district.delivery_considered.duplicate()
		for repetition: int in range(3):
			NpcDeliveryOfferService.refresh()
		_check(district.home_deliveries.size() == before.size() and before.size() >= 3, "reload does not create duplicate offers")
		_check(district.delivery_considered == considered, "daily selection restored")
		for index: int in district.home_deliveries.size():
			var job: NpcHomeDelivery = district.home_deliveries[index]
			var after: Array = [job.job_id, job.package_id, job.visit_id, job.npc_id, job.source, job.status, job.bonus, job.bargain, job.bargain_roll, job.published]
			_check(after == before[index], "IDs, price, source and decisions unchanged")
			_check(CustomerFlowService.parcel_for(job.package_id) != null, "real promised box survives reload")
			if job.source == NpcHomeDelivery.Source.PERSONAL:
				_check(not job.published and job.bargain == NpcHomeDelivery.Bargain.ACCEPTED, "personal bargain remains private")
		_check(district.home_deliveries.back().status == NpcHomeDelivery.Status.DECLINED, "decline remains final")
		var money_count: int = WalletService.current().operations.size()
		NpcHomeDeliveryService.finish_evening(1)
		NpcHomeDeliveryService.finish_evening(1)
		DayPhaseService.current().day_index = 2
		DistrictPopulationService.prepare_morning(2)
		NpcDeliveryOfferService.refresh()
		_check(district.home_deliveries.size() == before.size(), "next morning does not reoffer failed or declined orders")
		_check(WalletService.current().operations.size() == money_count, "night does not invent payments")
		var next_morning: Dictionary = WorldSnapshotService.capture(level, 2)
		_check(WorldSnapshotService.valid(next_morning, level), "next morning snapshot valid")
		_cleanup_slot()
	print("District delivery offers smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _check_invalid_delivery(snapshot: Dictionary, level: Node3D) -> void:
	var malformed: Dictionary = snapshot.duplicate(true)
	for entity: Dictionary in malformed.entities:
		for component: Dictionary in entity.components:
			if component.type == C_District.resource_path:
				var deliveries: Array = component.fields.home_deliveries as Array
				if not deliveries.is_empty():
					deliveries[0].fields.status = NpcHomeDelivery.Status.AMBUSHED + 1
	_check(not WorldSnapshotService.valid(malformed, level), "unknown delivery status rejected before restore")

func _cleanup_slot() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Delivery offers smoke: " + message)
#endregion
