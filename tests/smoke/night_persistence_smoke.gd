extends Node
## Two actual processes prove scheduled Night preparation and passive startup restore of the main
## level.

const SAVE_PATH: String = "user://night_persistence_smoke.pvzh"
const MAX_FRAMES: int = 600
const DELTA: float = 1.0 / 60.0
const EXPECTED_BALANCE: int = -275
const EXPECTED_HUNGER: float = 55.0
const EXPECTED_ELAPSED_TICKS: int = 123456789
const EXPECTED_TICK_REMAINDER: float = 0.625
const EXPECTED_WORLD_SEED: int = -42
const MISSING_SLOT: String = "user://night_persistence_smoke_missing/slot.pvzh"
const FURNITURE_OPERATION: StringName = &"night_smoke/furniture"
const LOOT_BATCH: String = "night_smoke/pending"
const NOTE: String = "Ночная запись [b]обычный текст[/b]\nСохранить один раз"
const RAW_PATH: NodePath = ^"Entityes/Props/Barrel_A_rigid"
const FOOD_SCENE_PATH: String = "res://content/domains/inventory/entities/food_pickup.tscn"
const UNLOAD_DISTANCE: float = 12.0

var _failed: bool = false


#region Scheduled save and process restart
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var restoring: bool = "restore" in OS.get_cmdline_user_args()
	if not restoring:
		_cleanup()
	var level: Node3D = (
		(load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	)
	level.set("autosave_path", SAVE_PATH)
	if not restoring:
		_configure_creation_seed(level)
	if restoring:
		var box: Node = level.get_node("Entityes/AnchorableTestBox")
		box.name = "RenamedPersistentBox"
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	(actor as Node as CharacterBody3D).set_physics_process(false)
	if restoring:
		_verify_restored(level, actor)
		if not _failed:
			await _retry_due_replacement(level)
	else:
		await _write_night(level, actor)
	level.free()
	if restoring:
		_cleanup()
	print(
		"Night persistence smoke ",
		"restore" if restoring else "write",
		": ",
		"FAIL" if _failed else "PASS",
	)
	get_tree().quit(1 if _failed else 0)


## Initialize the detached authored clock before population/placed-merchant variation is compiled.
func _configure_creation_seed(level: Node3D) -> void:
	var session: Entity = level.get_node("Entityes/DaySession") as Entity
	var recipes: Array[Component] = session.component_resources.duplicate()
	for index: int in recipes.size():
		if not recipes[index] is C_DayCycle:
			continue
		var calendar: C_DayCycle = recipes[index].duplicate(true) as C_DayCycle
		calendar.clock.world_seed = EXPECTED_WORLD_SEED
		recipes[index] = calendar
		session.component_resources = recipes
		return
	_check(false, "authored session exposes its creation clock recipe")


func _write_night(level: Node3D, actor: Entity) -> void:
	await _prepare_domains(level, actor)
	if _failed:
		return
	WalletService.current().balance = EXPECTED_BALANCE
	(actor.get_component(C_Hunger) as C_Hunger).value = EXPECTED_HUNGER
	var med: Entity = level.get_node("Entityes/MedPickup") as Entity
	_check(InventoryService.transfer(med, actor), "real inventory pickup accepted")
	var box: Entity = level.get_node("Entityes/AnchorableTestBox") as Entity
	var slot: Entity = level.get_node("Entityes/Player/BeltSlotLeft") as Entity
	var stored: Relationship = Relationship.new(R_StoredIn.new(), slot)
	box.add_relationship(stored)
	_check(PhysicalSlotService.attach(box, stored), "real physical slot attached")
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.clock.elapsed_ticks = EXPECTED_ELAPSED_TICKS
	cycle.clock.tick_remainder = EXPECTED_TICK_REMAINDER
	_check(
		cycle.clock.world_seed == EXPECTED_WORLD_SEED,
		"creation seed precedes roster publication",
	)
	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = false
	var initial_population: int = NpcPopulationQueries.current().people.size()
	var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one()
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = MISSING_SLOT
	_check(
		not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(MISSING_SLOT.get_base_dir())
		),
		"isolated write-error directory is absent",
	)
	for _frame: int in MAX_FRAMES:
		GameTimeFixture.gameplay(ECS.world, DELTA)
		if not state.prepared_snapshot.is_empty():
			break
		await get_tree().physics_frame
	_check(
		state.last_error != OK and state.last_error != ERR_INVALID_DATA
		and not state.prepared_snapshot.is_empty() and not cycle.night_ready,
		"real I/O failure follows complete immutable capture and holds Night",
	)
	if _failed:
		return
	var prepared: Dictionary = state.prepared_snapshot.duplicate(true)
	var population: int = NpcPopulationQueries.current().people.size()
	_check(population == initial_population, "authored replacement delay prevents early settlement")
	var operations: int = WalletService.current().operations.size()
	for _attempt: int in 3:
		state.retry_remaining = 0.0
		GameTimeFixture.gameplay(ECS.world, DELTA)
		_check(state.prepared_snapshot == prepared, "I/O retry retains identical value graph")
		_check(
			NpcPopulationQueries.current().people.size() == population,
			"replacement occurs once",
		)
		_check(
			WalletService.current().operations.size() == operations,
			"retry never repeats payment",
		)
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	GameTimeFixture.gameplay(ECS.world, DELTA)
	_check(
		cycle.night_ready and cycle.phase == C_DayCycle.Phase.NIGHT,
		"successful storage commit precedes the next Morning gameplay slice",
	)
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(snapshot == prepared, "successful write uses the exact prepared graph")
	_verify_domains(level, snapshot)
	for _frame: int in MAX_FRAMES:
		GameTimeFixture.gameplay(ECS.world, DELTA)
		if cycle.day_index == 2:
			break
		await get_tree().physics_frame
	_check(
		cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING,
		"actual Night owner completed prepared Morning",
	)
	_verify_clock(cycle)
	_check(
		not snapshot.is_empty() and snapshot.get("morning_day") == 2,
		"real atomic slot contains Morning 2",
	)
	_check(
		WorldSnapshotService.can_restore(snapshot, level),
		"saved prefab/recipe/link graph validates",
	)


func _verify_restored(level: Node3D, actor: Entity) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	_check(
		cycle.day_index == 2 and cycle.phase == C_DayCycle.Phase.MORNING,
		"new process restored Morning 2",
	)
	_verify_clock(cycle)
	_check(
		WalletService.current().balance == EXPECTED_BALANCE,
		"saved debt was not reset by startup",
	)
	_check(
		is_equal_approx((actor.get_component(C_Hunger) as C_Hunger).value, EXPECTED_HUNGER),
		"saved hunger overlay applied",
	)
	_check(InventoryService.items(actor).size() == 1, "one restored inventory item")
	var box: Entity = level.get_node("Entityes/RenamedPersistentBox") as Entity
	var slot: Entity = level.get_node("Entityes/Player/BeltSlotLeft") as Entity
	var links: Array[Relationship] = box.get_relationships(Relationship.new(R_StoredIn.new()))
	_check(
		links.size() == 1 and links[0].target == slot,
		"renamed authored body retains physical link by explicit ID",
	)
	_check(
		NpcPopulationQueries.current().prepared_morning == 2,
		"prepared district restored without preparing another Morning",
	)
	_check(
		MetaPresentation.debug_text().contains("Восстановлено утро 2"),
		"startup published restored readiness",
	)
	_verify_domains(level, AutosaveStore.read(SAVE_PATH), true)


## The restored session reaches the authored replacement morning and retries the same transaction.
func _retry_due_replacement(level: Node3D) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var district: C_District = NpcPopulationQueries.current()
	_check(
		district.replacement_morning == cycle.day_index + 1,
		"restored vacancy deadline follows the authored two-day delay",
	)
	var population: int = district.people.size()
	var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one()
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = MISSING_SLOT
	state.retry_remaining = 0.0
	cycle.phase = C_DayCycle.Phase.NIGHT
	cycle.night_ready = false
	for _frame: int in MAX_FRAMES:
		GameTimeFixture.gameplay(ECS.world, DELTA)
		if not state.prepared_snapshot.is_empty():
			break
		await get_tree().physics_frame
	_check(
		state.last_error != OK and state.last_error != ERR_INVALID_DATA
		and not state.prepared_snapshot.is_empty(),
		"replacement snapshot reaches real I/O failure: error=%d, prepared=%d, people=%d"
		% [state.last_error, state.prepared_snapshot.size(), district.people.size()],
	)
	if _failed:
		return
	var prepared: Dictionary = state.prepared_snapshot.duplicate(true)
	var operations: int = WalletService.current().operations.size()
	_check(district.people.size() == population + 1, "one actual replacement is committed")
	for _attempt: int in 3:
		state.retry_remaining = 0.0
		GameTimeFixture.gameplay(ECS.world, DELTA)
		_check(
			district.people.size() == population + 1,
			"replacement I/O retry never settles twice",
		)
		_check(
			WalletService.current().operations.size() == operations,
			"replacement retry never repays",
		)
		_check(state.prepared_snapshot == prepared, "replacement retries keep one prepared graph")
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	GameTimeFixture.gameplay(ECS.world, DELTA)
	var snapshot: Dictionary = AutosaveStore.read(SAVE_PATH)
	_check(cycle.night_ready and snapshot == prepared, "replacement morning written atomically")
	_check(
		WorldSnapshotService.restore(snapshot, level),
		"replacement world reloads without duplicates",
	)
	_verify_domains(level, snapshot, true)
	_check(
		NpcPopulationQueries.current().people.size() == population + 1,
		"reloading the replacement does not create another resident",
	)
#endregion


#region Representative district state through real operation boundaries
func _prepare_domains(level: Node3D, actor: Entity) -> void:
	var zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	ReceivingDeliveryService.prepare_batch(zone.supply, receiving, 1)
	var truck: E_MorningTruck = zone.ensure_truck()
	truck.door_animation.advance(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for _frame: int in MAX_FRAMES:
		ReceivingDeliveryService.deliver_one(zone, receiving, 1)
		for index: int in receiving.incoming_package_ids.size():
			var parcel: Entity = PackageQueries.find_live_package(
				receiving.incoming_package_ids[index]
			)
			if parcel == null:
				continue
			var marker: Node3D = zone.get_spawn_points().get_child(index) as Node3D
			var body: RigidBody3D = parcel as Node as RigidBody3D
			body.freeze = true
			body.global_transform = marker.global_transform
			body.global_position += truck.global_basis.x * UNLOAD_DISTANCE
		if receiving.pending.is_empty():
			break
		await get_tree().physics_frame
	_check(
		receiving.incoming_package_ids.size() == 5 and receiving.pending.is_empty(),
		"real five-package manifest unloaded",
	)
	if _failed:
		return

	var selected: CustomerVisit = null
	for visit: CustomerVisit in CustomerFlowQueries.current().visits:
		var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
		_check(
			PackageRegistrationService.register_package(parcel).number > 0,
			"real parcel registered",
		)
		if selected == null and HomeDeliveryQueries.visit_available(visit, 1):
			selected = visit
	_check(selected != null, "registered resident order can receive a personal offer")
	if selected == null:
		return
	var job: NpcHomeDelivery = NpcDeliveryOfferService.assign_personal(selected.visit_id, &"", true)
	_check(job != null, "personal published offer materialized")
	if job == null:
		return
	_check(
		NpcDeliveryOfferService.negotiate(job.job_id) != NpcHomeDelivery.Bargain.NONE,
		"one bargain answer captured",
	)
	_check(NpcDeliveryOfferService.accept(job.job_id), "promise accepted before Night")
	var history: PackageRegistrationRecord = PackageHistoryService.record_for(selected.package_id)
	_check(PackageHistoryService.update_note(history.history_id, NOTE), "history note committed")
	for visit: CustomerVisit in CustomerFlowQueries.current().visits:
		if visit != selected:
			_check(
				CustomerOutcomeService.create_complaint(
					visit,
					1,
					CustomerComplaint.Reason.NOT_DELIVERED,
					true,
				),
				"real complaint captured",
			)
			var entry: PackageRegistrationRecord = PackageHistoryService.record_for(
				visit.package_id
			)
			var notice: TerminalPackageNotice = TerminalPackageNoticeService.present(entry, visit)
			_check(notice.event_ids.size() == 1, "real complaint notification available")
			_check(
				TerminalPackageNoticeService.mark_read(entry.history_id, notice.event_ids),
				"actual notification read state committed",
			)
			break

	WalletService.current().balance = 1000
	var shelf: DEF_InventoryItem = (
		load("res://content/domains/inventory/definitions/def_item_large_shelf.tres")
		as DEF_InventoryItem
	)
	_check(
		CommerceService.home_delivery(
			actor,
			NpcActivityService.merchant(),
			shelf,
			1,
			FURNITURE_OPERATION,
		)
		== CommerceService.Status.COMMITTED,
		"paid next-morning furniture",
	)
	# Unsupported terrain leaves a real queued drop; no per-frame fixture spawning.
	var queue: C_LootDrops = LootDropService.current()
	var template: PendingLootDrop = PendingLootDrop.new()
	template.origin = Vector3(10000, 10000, 10000)
	template.anchor = template.origin
	var loot_scene: PackedScene = load(FOOD_SCENE_PATH) as PackedScene
	var items: Array[Entity] = LootDropService.prepare([loot_scene])
	_check(
		LootDropService.enqueue(queue, LOOT_BATCH, items, template).is_empty(),
		"blocked real drop remains pending",
	)
	_check(queue.pending.size() == 1, "one pending loot identity")

	var sale: Entity = loot_scene.instantiate() as Entity
	level.add_child(sale)
	EntityCompositionFixture.register(ECS.world, sale, false)
	_check(EntityAvailability.contains(sale, ECS.world), "physical resale item registered")
	(sale as Node as RigidBody3D).freeze = true
	(sale as Node as Node3D).global_transform = truck.cargo_slots[0].global_transform
	var raw: RigidBody3D = level.get_node(RAW_PATH) as RigidBody3D
	raw.gravity_scale = 0.0
	raw.global_transform = truck.cargo_slots[1].global_transform
	_check(PhysicsGrabTarget.handle_for(raw, true) != null, "raw cargo uses real transient proxy")
	var gate: ReceivingShiftService.Status = ReceivingShiftService.status(DayPhaseQueries.current())
	_check(
		ReceivingShiftService.commit_departure(DayPhaseQueries.current()),
		"cargo transaction committed; gate: " + "; ".join(gate.reasons),
	)
	_check(receiving.cargo_receipts.size() == 2, "one resale and one raw disposal receipt")
	_check(level.get_node_or_null(RAW_PATH) == null, "native placement disposed before capture")

	var district: C_District = NpcPopulationQueries.current()
	var deaths: int = 0
	for person: NpcRecord in district.people.duplicate():
		if person.npc_id == selected.customer_id or not person.profile.resident:
			continue
		DistrictPopulationService.mark_dead(person, NpcPopulationQueries.body_for(person.npc_id), 1)
		deaths += 1
		if deaths == 2:
			break
	_check(deaths == 2, "two permanent deaths require one replacement")
	var retained: NpcRecord = NpcPopulationQueries.person_for(selected.customer_id)
	var retained_body: E_DistrictNpc = NpcPopulationQueries.body_for(retained.npc_id)
	(retained_body.get_component(C_Health) as C_Health).current = 41.0
	DistrictPopulationService.set_placement(retained, retained_body, NpcRecord.Placement.OUTSIDE)


func _verify_domains(level: Node3D, snapshot: Dictionary, after_ready: bool = false) -> void:
	var domains: Array[Script] = [
		C_PackageLedger,
		C_CustomerFlow,
		C_District,
		C_LootDrops,
		C_Commerce,
		C_Receiving,
		C_Wallet,
	]
	var saved: Dictionary[String, Dictionary] = { }
	for record: Dictionary in snapshot.entities:
		saved[String(record.key)] = record
	for owner: Entity in ECS.world.entities:
		var key: String = ActorIdentityRules.key_for(owner, level)
		for domain: Script in domains:
			if not owner.has_component(domain):
				continue
			_check(saved.has(key), "domain owner restored by stable identity")
			if not saved.has(key):
				continue
			var actual: Dictionary = SaveDataCodec.component_data(owner.get_component(domain))
			var expected: Array = saved[key].components as Array
			if after_ready:
				expected = _expected_ready_components(
					expected, domain, int(snapshot.morning_day)
				)
			_check(
				expected.has(actual),
				"full durable aggregate matches stored " + domain.resource_path,
			)
	var zone: Entity = level.get_node("Entityes/ReceivingZone") as Entity
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	_check(receiving.cargo_receipts.size() == 2, "cargo history survives restart")
	_check(level.get_node_or_null(RAW_PATH) == null, "raw tombstone removes native fresh placement")
	_check(LootDropService.current().pending.size() == 1, "pending loot survives restart")
	_check(
		CommerceService.current().pending_deliveries.size() == 1,
		"paid furniture survives restart",
	)
	_check(CommerceService.current().receipts.size() == 1, "purchase receipt is not repeated")
	var notes: int = 0
	for history: PackageRegistrationRecord in PackageQueries.ledger().records:
		if history.note == NOTE:
			notes += 1
	_check(notes == 1, "one stable history note")
	var acknowledged_complaints: int = 0
	for visit: CustomerVisit in CustomerFlowQueries.current().visits:
		if visit.complaint == null:
			continue
		var entry: PackageRegistrationRecord = PackageHistoryService.record_for(visit.package_id)
		var initial_event: String = "complaint/%s/%d/0" % [
			visit.complaint.complaint_id,
			CustomerComplaint.Outcome.PENDING,
		]
		if entry.read_event_ids.has(initial_event):
			acknowledged_complaints += 1
	_check(acknowledged_complaints == 1, "original complaint acknowledgement survives newer events")
	var failed_promises: int = 0
	for job: NpcHomeDelivery in NpcPopulationQueries.current().home_deliveries:
		if job.status == NpcHomeDelivery.Status.FAILED:
			failed_promises += 1
			_check(job.bargain != NpcHomeDelivery.Bargain.NONE, "bargain result survives Night")
			var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
			_check(person.memories.size() == 1, "one broken-promise memory after retries/restart")
			var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
			_check(body != null, "retained resident body restored")
			if body != null:
				_check(
					(body.get_component(C_Health) as C_Health).current == 41.0,
					"absent resident keeps authoritative body Health",
				)
	_check(failed_promises == 1, "one failed promise preserved")
	var deaths: int = 0
	for person: NpcRecord in NpcPopulationQueries.current().people:
		if person.death_day == 1:
			deaths += 1
	_check(deaths == 2, "dead permanent identities survive replacement and restart")
#endregion


#region Ready reconciliation expectations
## The file stores Night preparation; ready now commits Morning reconciliation before any tick.
## Keep exact comparison of every durable field, allowing only these evidenced phase-entry changes.
func _expected_ready_components(rows: Array, domain: Script, morning_day: int) -> Array:
	var expected: Array = rows.duplicate(true)
	for row: Dictionary in expected:
		if String(row.type) != domain.resource_path:
			continue
		var fields: Dictionary = row.fields as Dictionary
		if domain == C_District:
			_check(
				fields.conflict_phase == StringName("%d/0" % [morning_day - 1]),
				"Night retains its original conflict phase",
			)
			fields.conflict_phase = StringName("%d/%d" % [morning_day, C_DayCycle.Phase.MORNING])
		elif domain == C_Wallet:
			var days: Array = fields.daily_results as Array
			var existing: bool = false
			for day: Dictionary in days:
				if int(day.fields.day_index) == morning_day:
					existing = true
			if not existing:
				# Ready opens the operation-free Morning; every stored result stays exact.
				var opened: DailyMoneyResult = DailyMoneyResult.new()
				opened.day_index = morning_day
				opened.closing_balance = int(fields.balance)
				days.append(SaveDataCodec.encode(opened))
		elif domain == C_CustomerFlow:
			_check(
				fields.planned_through_day == morning_day - 1,
				"Night retains the delivered-day watermark",
			)
			fields.planned_through_day = morning_day
			for visit: Dictionary in fields.visits:
				var visit_fields: Dictionary = visit.fields as Dictionary
				if visit_fields.complaint == null:
					continue
				var complaint_fields: Dictionary = visit_fields.complaint.fields as Dictionary
				if complaint_fields.outcome != CustomerComplaint.Outcome.PENDING:
					continue
				_check(visit_fields.customer_dead, "fixture complaint belongs to a dead claimant")
				_check(
					complaint_fields.resolve_day <= morning_day,
					"pending fixture complaint is due at ready",
				)
				complaint_fields.outcome = CustomerComplaint.Outcome.NO_LIVING_CLAIMANT
				complaint_fields.resolved_day = morning_day
	return expected
#endregion


#region Deterministic smoke reporting
func _verify_clock(cycle: C_DayCycle) -> void:
	_check(
		cycle.clock.elapsed_ticks == EXPECTED_ELAPSED_TICKS,
		"Night and restart retain elapsed ticks",
	)
	_check(cycle.clock.tick_remainder == EXPECTED_TICK_REMAINDER, "restart retains fractional tick")
	_check(cycle.clock.world_seed == EXPECTED_WORLD_SEED, "restart retains decision world seed")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var filename: String = ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(filename)
#endregion
