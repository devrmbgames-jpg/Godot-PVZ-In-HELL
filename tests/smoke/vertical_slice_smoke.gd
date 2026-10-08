extends Node
## Current main-level contracts: manifest, ledger, terminal settlement, ownership, damage, Night and startup restore.

const SAVE_PATH: String = "user://vertical_slice_smoke.pvzh"
const DELTA: float = 1.0 / 60.0
const MAX_RECEIVING_FRAMES: int = 900
const MAX_NIGHT_FRAMES: int = 600
const DAMAGE_AMOUNT: float = 2.0
const MAIN: PackedScene = preload("res://content/scenes/main_level.tscn")

var _level: Node3D
var _failed: bool = false

#region Connected production contracts
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup_slot()
	_level = MAIN.instantiate() as Node3D
	_level.set("autosave_path", SAVE_PATH)
	add_child(_level)
	_level.set_physics_process(false)

	var expected: Dictionary = await _exercise_current_world()
	_level.free()
	_level = null
	await get_tree().process_frame
	if not _failed:
		await _verify_fresh_startup(expected)
	if _level != null:
		_level.free()
		_level = null
	_cleanup_slot()
	await get_tree().process_frame
	print("Vertical slice smoke ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _exercise_current_world() -> Dictionary:
	var world: World = ECS.world
	var zone: E_ReceivingZone = world.query.with_all([C_Receiving]).execute_one() as E_ReceivingZone
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	# Body motion stays native; only the scene's scheduler is stepped explicitly below.
	if not _check((actor as Node) is CharacterBody3D, "current authored CharacterBody player"):
		return {}
	if not await _receive_and_unload(world, zone, receiving):
		return {}

	_audit_customer_query("received")
	var ids: PackedStringArray = receiving.incoming_package_ids.duplicate()
	var flow: C_CustomerFlow = CustomerFlowService.current()
	if not _check(flow.visits.size() == ids.size(), "one planned customer record per provider-selected package"):
		return {}
	for package_id: String in ids:
		var parcel: Entity = CustomerFlowService.parcel_for(package_id)
		if not _check(parcel != null, "physical package exists: " + package_id):
			return {}
		var scanned: PackageScanResult = PackageRegistrationService.register_package(parcel)
		_check(scanned.outcome == PackageScanResult.Outcome.REGISTERED, "ledger commits registration")
		_check(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.ALREADY_REGISTERED,
			"repeated registration is idempotent")
		_check(PackageHistoryService.record_for(package_id).number > 0, "registered history visible immediately")
	if _failed:
		return {}

	# Use the existing trusted terminal declaration API, not a fabricated delivery receipt.
	var visit: CustomerVisit = flow.visits[0]
	var wallet: C_Wallet = WalletService.current()
	var operations_before: int = wallet.operations.size()
	_check(CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.LOST), "terminal LOST declaration commits")
	_check(visit.settlement_committed and wallet.operations.size() == operations_before + 1,
		"committed customer fact settles once through the production Observer")
	var settled_balance: int = wallet.balance
	CustomerOutcomeService.publish_change(visit, &"smoke_replay")
	_check(CustomerOutcomeService.declare(visit, CustomerVisit.Declaration.LOST), "repeated declaration acknowledged")
	_check(wallet.balance == settled_balance and wallet.operations.size() == operations_before + 1,
		"fact replay cannot settle twice")

	var med: Entity = _level.get_node("Entityes/MedPickup") as Entity
	_check(InventoryService.transfer(med, actor), "real pickup transferred into inventory")
	_check(InventoryService.owner_for(med) == actor and InventoryService.items(actor).size() == 1,
		"authoritative ownership link and derived inventory agree")
	var health: C_Health = actor.get_component(C_Health) as C_Health
	var previous_health: float = health.current
	var damage: DamageRequest = DamageRequest.new()
	damage.target = actor
	damage.amount = DAMAGE_AMOUNT
	_check(DamageRequestService.submit(damage), "typed damage accepted by sole handler")
	_check(health.current < previous_health and not health.depleted, "applied health visible after damage completion")
	if _failed:
		return {}

	await _step(world, 3)
	var cycle: C_DayCycle = DayPhaseService.current()
	var shift: DayTransitionRequest = DayTransitionRequest.new()
	shift.expected_day = cycle.day_index
	shift.expected_phase = cycle.phase
	if not _check(DayPhaseService.submit(shift), "unloaded registered manifest permits shift: " + str(DayPhaseService.start_blockers(cycle))):
		return {}
	_check(cycle.phase == C_DayCycle.Phase.MORNING, "accepted transition remains pending before System commit")
	await _step(world, 1)
	_check(cycle.phase == C_DayCycle.Phase.DAY and cycle.pending_transition == null, "scheduled shift owner commits phase")
	if _failed:
		return {}

	# Enter the same Night gate as its dedicated smoke; preparation/capture/write remain production-owned.
	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = false
	for _frame: int in MAX_NIGHT_FRAMES:
		await _step(world, 1)
		if cycle.phase == C_DayCycle.Phase.MORNING and cycle.day_index == 2:
			break
	_check(cycle.phase == C_DayCycle.Phase.MORNING and cycle.day_index == 2, "scheduled Night prepared Morning 2")
	_audit_customer_query("source_after_night")
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(not snapshot.is_empty() and WorldSnapshotService.can_restore(snapshot, _level), "actual atomic Night snapshot validates")
	var saved_balance: int = 0
	var saved_operations: int = 0
	var wallet_record_found: bool = false
	for record: Dictionary in snapshot.get("entities", []):
		for component: Dictionary in record.components:
			if component.type == C_Wallet.resource_path:
				saved_balance = int(component.fields.balance)
				saved_operations = (component.fields.operations as Array).size()
				wallet_record_found = true
	_check(wallet_record_found, "captured snapshot contains the authoritative Wallet aggregate")
	return {"balance": wallet.balance, "operations": wallet.operations.size(), "saved_balance": saved_balance,
		"saved_operations": saved_operations, "health": health.current, "visit_id": visit.visit_id,
		"package_ids": ids, "player_key": ActorIdentityRules.key_for(actor, _level)}



func _receive_and_unload(world: World, zone: E_ReceivingZone, receiving: C_Receiving) -> bool:
	var unloaded: Dictionary[String, bool] = {}
	var used_markers: Dictionary[int, bool] = {}
	for _frame: int in MAX_RECEIVING_FRAMES:
		await _step(world, 1)
		for parcel: Entity in world.query.with_all([C_Package]).execute():
			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			if not receiving.incoming_package_ids.has(identity.package_id) or unloaded.has(identity.package_id):
				continue
			if not _place_outside_truck(zone, parcel, used_markers):
				return false
			unloaded[identity.package_id] = true
		if receiving.last_started_day == 1 and not receiving.incoming_package_ids.is_empty() and receiving.pending.is_empty():
			break
	return _check(receiving.last_started_day == 1 and receiving.pending.is_empty()
		and unloaded.size() == receiving.incoming_package_ids.size() and not unloaded.is_empty(),
		"scheduled receiving completes the current provider-selected manifest without duplicate bodies")


func _place_outside_truck(zone: E_ReceivingZone, parcel: Entity, used_markers: Dictionary[int, bool]) -> bool:
	# Only this fixture models carrying; production containment decides which authored marker is outside cargo.
	var body: RigidBody3D = parcel as Node as RigidBody3D
	for marker_index: int in zone.get_spawn_points().get_child_count():
		if used_markers.has(marker_index):
			continue
		var marker: Node3D = zone.get_spawn_points().get_child(marker_index) as Node3D
		body.global_transform = marker.global_transform
		if zone.get_truck().overlaps_cargo(body):
			continue

		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
		used_markers[marker_index] = true
		return true
	return _check(false, "authored warehouse has enough unload markers outside actual cargo bounds")


func _step(world: World, frames: int) -> void:
	for _frame: int in frames:
		for group_name: String in ["Input", "Interaction", "Physics", "GamePlay"]:
			world.process(DELTA, group_name)
		await get_tree().physics_frame
#endregion

#region Fresh authored startup and cleanup
func _verify_fresh_startup(expected: Dictionary) -> void:
	_level = MAIN.instantiate() as Node3D
	_level.set("autosave_path", SAVE_PATH)
	_level.get_node("Entityes/AnchorableTestBox").name = "RenamedPersistentBox"
	add_child(_level)
	_level.set_physics_process(false)
	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	var cycle: C_DayCycle = DayPhaseService.current()
	_check(cycle.phase == C_DayCycle.Phase.MORNING and cycle.day_index == 2, "fresh startup restored saved Morning")
	_check(ActorIdentityRules.key_for(actor, _level) == expected.player_key, "explicit placed player identity survives new instance")
	_check(WalletService.current().balance == expected.saved_balance
		and WalletService.current().operations.size() == expected.saved_operations,
		"passive startup overlays the captured Wallet before scheduled Morning entry")
	_check(is_equal_approx((actor.get_component(C_Health) as C_Health).current, float(expected.health)),
		"saved damaged player health overlays the native recipe")
	_check(InventoryService.items(actor).size() == 1, "one restored inventory item and live owner binding")
	_audit_customer_query("fresh_before_tick")
	# Capture precedes the live Morning-entry fact. The first restored step consumes the same entry once.
	await _step(ECS.world, 1)
	_audit_customer_query("fresh_after_tick")
	_check(WalletService.current().balance == expected.balance and WalletService.current().operations.size() == expected.operations,
		"first scheduled Morning entry matches the original continuation, without lost or duplicate settlement")
	var visit: CustomerVisit = CustomerFlowService.find_visit(expected.visit_id)
	if not _check(visit != null and visit.settlement_committed and visit.declaration == CustomerVisit.Declaration.LOST,
			"terminal customer settlement remains committed"):
		return
	var wallet: C_Wallet = WalletService.current()
	var operation_count: int = wallet.operations.size()
	var balance: int = wallet.balance
	CustomerOutcomeService.publish_change(visit, &"smoke_restored_replay")
	_check(wallet.operations.size() == operation_count and wallet.balance == balance, "restored fact replay cannot charge again")
	for package_id: String in expected.package_ids:
		_check(PackageHistoryService.record_for(package_id) != null, "stable package history survives startup restore")


func _audit_customer_query(stage: String) -> void:
	for subject: Entity in ECS.world.query.with_all([C_Challenge, C_CustomerAgent]).execute():
		_check(subject.has_component(C_CustomerAgent) and subject.has_component(C_Challenge),
			"required query components agree with restored actor state: " + stage)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failed = true
		push_error("Vertical slice smoke: " + message)
	return condition


func _cleanup_slot() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var filename: String = ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(filename)
#endregion
