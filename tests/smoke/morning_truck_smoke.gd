extends Node
## Два процесса настоящего района: занятый кузов, сохранённый остаток, разгрузка и повтор восстановления.

const SAVE_PATH: String = "user://morning_truck_smoke.pvzh"
const MAX_FRAMES: int = 480
var _failed: bool = false

#region Полный район и реальная поставка
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup()
	var level: Node3D = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	level.set("autosave_path", "")
	add_child(level)
	level.set_physics_process(false)
	var zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone

	if restoring:
		var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
		_check(WorldSnapshotService.valid(snapshot, level), "saved district validates")
		_check(WorldSnapshotService.restore(snapshot, level), "pending batch restores in new process")
		if not _failed:
			await _unload_and_finish(level, zone)
		_cleanup()
	else:
		await _prepare_and_save(level, zone)
	print("Morning truck smoke ", "restore" if restoring else "write", ": ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _prepare_and_save(level: Node3D, zone: E_ReceivingZone) -> void:
	var state: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	ReceivingDeliveryService.prepare_batch(zone.supply, state, 1)
	_check(state.incoming_package_ids.size() == 5, "original five-package supply")
	var truck: E_MorningTruck = zone.ensure_truck()
	_check(truck != null and truck.global_transform.is_equal_approx(zone.truck_parking.global_transform), "authored parking and orientation")
	if _failed:
		return
	truck.cargo_slots.assign([truck.cargo_slots[0]])
	truck.door_animation.advance(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(zone, state, 1)
	_check(_count() == 1, "real first box loaded inside authored truck")
	if _failed:
		return
	for frame: int in 12:
		await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(zone, state, 1)
	_check(state.blocked and state.pending[0].next_package == 1, "occupied cargo preserves remainder")
	var first_id: String = state.incoming_package_ids[0]
	var arrival: PackageRegistrationRecord = PackageHistoryService.record_for(first_id)
	_check(arrival != null and arrival.number == 0, "terminal receipt without registration number")
	var saved: Dictionary = WorldSnapshotService.capture(level, 1)
	_check(WorldSnapshotService.valid(saved, level), "pending full-world snapshot validates")
	_check(AutosaveStore.write(saved, SAVE_PATH) == OK, "pending cargo persisted to own slot")


func _unload_and_finish(level: Node3D, zone: E_ReceivingZone) -> void:
	var state: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	_check(state.batch_id == "base_supply:1" and state.incoming_package_ids.size() == 5, "stable restored manifest")
	_check(state.pending.size() == 1 and state.pending[0].next_package == 1 and _count() == 1, "one existing box and four pending")
	_check(state.retry_remaining == 0.0 and state.reservations.is_empty(), "runtime caches rebuilt")
	var ids: PackedStringArray = state.incoming_package_ids.duplicate()
	var unloaded: Dictionary[String, bool] = {}
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		ECS.world.process(1.0 / 60.0, "GamePlay")
		for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			if unloaded.has(identity.package_id):
				continue
			# Только smoke переносит тело: моделирует физический вынос игроком на прежние места склада.
			var marker: Node3D = zone.get_spawn_points().get_child(unloaded.size()) as Node3D
			var body: RigidBody3D = parcel as Node as RigidBody3D
			body.global_transform = marker.global_transform
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
			unloaded[identity.package_id] = true
		if state.pending.is_empty():
			break
	_check(state.pending.is_empty() and _count() == 5, "unloading resumes and completes original batch")
	_check(state.incoming_package_ids == ids and state.delivered_counts.get(1) == 5, "same manifest and one delivery per position")
	for package_id: String in ids:
		var receipt: PackageRegistrationRecord = PackageHistoryService.record_for(package_id)
		_check(receipt != null and receipt.number == 0, "one real unregistered receipt for " + package_id)
	var truck: E_MorningTruck = zone.get_truck()
	_check(truck != null and zone.ensure_truck() == truck, "one reconstructed runtime truck")
	var finished: Dictionary = WorldSnapshotService.capture(level, 1)
	_check(WorldSnapshotService.restore(finished, level), "completed batch restores")
	_check(WorldSnapshotService.restore(finished, level), "repeated restore does not duplicate cargo")
	for frame: int in 30:
		await get_tree().physics_frame
		ECS.world.process(1.0 / 60.0, "GamePlay")
	_check(_count() == 5 and state.pending.is_empty(), "long morning keeps exactly five boxes")
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	ECS.world.process(1.0 / 60.0, "GamePlay")
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		if zone.get_truck() == null:
			break
	_check(zone.get_truck() == null and _count() == 5, "finite door lifecycle leaves unloaded boxes")


func _count() -> int:
	return ECS.world.query.with_all([C_Package]).execute().size()
#endregion


#region Результат и собственный слот
func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("Morning truck smoke: " + message)


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
#endregion
