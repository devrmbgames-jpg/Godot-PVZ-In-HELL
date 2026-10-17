extends "res://tests/gut/test_npc_life_cycle.gd"
## Реальные заказы переживают отсутствие, фактическое возвращение, диск и однократную выдачу.

const ORDER_SCHEDULE: DEF_CustomerSchedule = preload(
	"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
)


#region Настоящие заказы и календарь
func before_each() -> void:
	super.before_each()
	CustomerFlowFixture.install()
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_CustomerFlow.new())
	session.add_component(C_Wallet.new())
	session.add_component(C_PackageLedger.new())
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	_world.add_observer(O_GrabLifecycle.new())


func _visit(suffix: String, arrival_day: int = 1) -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = StringName("return/case/" + suffix)
	visit.customer_id = &"npc/3"
	visit.package_id = "return/" + suffix
	visit.arrival_day = arrival_day
	visit.payment = 10
	visit.definition = ORDER_SCHEDULE.events[0].customer
	visit.requires_registered_package = false
	CustomerFlowQueries.current().visits.append(visit)
	return visit


func _accepted(suffix: String) -> NpcHomeDelivery:
	var visit: CustomerVisit = _visit(suffix)
	var parcel: E_Package = (
		load("res://content/domains/packages/entities/package_a.tscn") as PackedScene
	).instantiate() as E_Package
	parcel.package_id = visit.package_id
	# Schedule._init загружает supply в runtime; editor parser не исполняет этот non-tool init.
	var supply: DEF_Delivery = ORDER_SCHEDULE.supply
	parcel.package_definition = supply.packages[0]
	EntityCompositionFixture.register(_world, parcel)
	assert_eq(
		PackageRegistrationService.register_package(parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	var job: NpcHomeDelivery = NpcDeliveryOfferService.assign_personal(visit.visit_id, &"", true)
	assert_not_null(job)
	assert_true(NpcDeliveryOfferService.accept(job.job_id))
	return job


func _door(address_id: StringName) -> Entity:
	for door: Entity in _world.query.with_all([C_NpcAddress]).execute():
		if (door.get_component(C_NpcAddress) as C_NpcAddress).address_id == address_id:
			return door
	return null


func _return_during_night(target_day: int) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = target_day - 1
	cycle.phase = C_DayCycle.Phase.NIGHT
	var receipt: DistrictMorningPreparationRequest = DistrictPopulationService.prepare_morning(
		target_day
	)
	assert_true(receipt.completed and receipt.succeeded)
	_world.flush_command_buffers()
	assert_eq(cycle.day_index, target_day - 1)


func _roundtrip(morning: int) -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, morning)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))


func _player_actor() -> Entity:
	var physical: RigidBody3D = RigidBody3D.new()
	physical.set_script(E_RigidBodyCharacter)
	var player: Entity = physical as Node as Entity
	var anchor: Marker3D = Marker3D.new()
	physical.add_child(anchor)
	(player as E_RigidBodyCharacter).head_axis_x = anchor
	(player as E_RigidBodyCharacter).hold_anchor = anchor
	player.component_resources = [
		C_PlayerInputController.new(),
		C_GrabControl.new(),
		C_Health.new(),
		C_Controller.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_Motion.new(),
	]
	_world.add_entity(player)
	physical.freeze = true
	physical.set_physics_process(false)
	return player

#endregion


#region Отсутствие, действительный срок и старые нарушения
func test_accepted_delivery_keeps_identity_and_pauses_until_actual_return() -> void:
	var job: NpcHomeDelivery = _accepted("paused")
	var job_id: StringName = job.job_id
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	var parcel: Entity = PackageQueries.find_live_package(job.package_id)
	var package_id: String = parcel.id
	var history: String = job.package_history_id
	var bonus: int = job.bonus
	_kill(person)
	assert_false(visit.customer_dead)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_eq(visit.declaration, CustomerVisit.Declaration.NONE)
	assert_eq(visit.absence_sequence, 1)
	assert_false(CustomerFlowQueries.visit_due(visit, 2))
	assert_eq(CustomerFlowFixture.reactivate(CustomerFlowQueries.current(), 2), 0)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 0)
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	assert_true(NpcHomeDeliveryService.finish_evening(2))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_eq(WalletService.current().operations.size(), 0)
	_morning(2)
	_roundtrip(2)
	job = HomeDeliveryQueries.find(job_id)
	visit = CustomerFlowQueries.find_visit(job.visit_id)
	assert_eq(visit.absence_sequence, 1)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 0)
	assert_eq(PackageQueries.find_live_package(job.package_id).id, package_id)
	_return_during_night(3)
	assert_eq(visit.absence_sequence, 0)
	assert_eq(visit.next_followup_day, 4)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 4)
	assert_eq(job.deadline_day, 2)
	assert_eq(job.day_index, 1)
	assert_eq(job.package_history_id, history)
	assert_eq(job.bonus, bonus)
	assert_eq(_district.home_deliveries.size(), 1)
	assert_eq(visit.followup_count, 0)
	assert_true(NpcHomeDeliveryService.finish_evening(2))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	_roundtrip(3)


func test_blocked_actual_return_keeps_deadline_paused_then_uses_later_day() -> void:
	var job: NpcHomeDelivery = _accepted("blocked")
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	_kill(person)
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 3.0)
	collision.shape = shape
	blocker.add_child(collision)
	_root.add_child(blocker)
	blocker.global_position = NpcPopulationQueries.position_for(person.home_id, true) + Vector3.UP
	await get_tree().physics_frame
	_morning(3)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 0)
	assert_true(NpcHomeDeliveryService.finish_evening(3))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	blocker.free()
	await get_tree().physics_frame
	_morning(4)
	assert_eq(person.deaths[0].returned_day, 4)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 5)
	assert_eq(CustomerFlowQueries.find_visit(job.visit_id).next_followup_day, 5)


func test_repeat_absence_extends_same_promise_and_final_failure_is_once() -> void:
	var job: NpcHomeDelivery = _accepted("twice")
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	_kill(person)
	_morning(3)
	_kill(person)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 0)
	_morning(5)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 6)
	assert_true(NpcHomeDeliveryService.finish_evening(4))
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_true(NpcHomeDeliveryService.finish_evening(5))
	assert_eq(job.status, NpcHomeDelivery.Status.FAILED)
	var memories: int = person.memories.size()
	NpcHomeDeliveryService.finish_evening(5)
	assert_eq(person.memories.size(), memories)
	assert_eq(_district.home_deliveries.size(), 1)


func test_already_broken_promise_and_old_claims_are_not_cleared_by_death() -> void:
	var job: NpcHomeDelivery = _accepted("broken")
	assert_true(NpcHomeDeliveryService.finish_evening(1))
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	var old: CustomerVisit = _visit("old_claim")
	old.declaration = CustomerVisit.Declaration.TAKEN
	old.complaint = CustomerComplaint.new()
	old.complaint.outcome = CustomerComplaint.Outcome.PENDING
	old.finished = true
	var encoded: Variant = SaveDataCodec.encode(old)
	var memory: Variant = SaveDataCodec.encode(person.memories)
	_kill(person)
	assert_eq(SaveDataCodec.encode(old), encoded)
	assert_eq(SaveDataCodec.encode(person.memories), memory)
	assert_false(old.customer_dead)
	assert_eq(job.status, NpcHomeDelivery.Status.FAILED)
	_morning(3)
	assert_eq(SaveDataCodec.encode(old), encoded)
	assert_eq(job.status, NpcHomeDelivery.Status.FAILED)


func test_unstarted_order_resumes_same_appointment_without_random_followup() -> void:
	var visit: CustomerVisit = _visit("counter", 4)
	var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
	_kill(person)
	assert_eq(visit.absence_sequence, 1)
	assert_true(visit.finished)
	assert_eq(visit.next_followup_day, 4)
	_morning(3)
	assert_eq(visit.absence_sequence, 0)
	assert_eq(CustomerFlowFixture.reactivate(CustomerFlowQueries.current(), 3), 0)
	assert_eq(CustomerFlowFixture.reactivate(CustomerFlowQueries.current(), 4), 1)
	assert_eq(visit.followup_count, 0)
	assert_false(visit.finished)
	assert_null(visit.complaint)
	assert_eq(visit.visit_count, 0)


func test_death_after_missed_deadline_does_not_retroactively_extend_it() -> void:
	var job: NpcHomeDelivery = _accepted("late_death")
	DayPhaseQueries.current().day_index = 2
	_kill(NpcPopulationQueries.person_for(job.npc_id))
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 2)
	assert_true(NpcHomeDeliveryService.finish_evening(2))
	assert_eq(job.status, NpcHomeDelivery.Status.FAILED)
#endregion


#region Реальная выдача, деньги, UI и ночное сохранение
func test_returned_recipient_gets_real_held_box_and_exactly_one_bonus() -> void:
	# Фикстура выбирает ветку принятия при настоящем авторском осмотре, без подмены receive.
	for seed: int in 16:
		GameTimeQueries.current().world_seed = seed
		var choice: RandomNumberGenerator = GameTimeQueries.decision(
			"return/case/paid",
			3,
			"customer/inspection/keep",
			1,
		)
		if choice.randf() < ORDER_SCHEDULE.events[0].customer.inspection_keep_probability:
			break
	var job: NpcHomeDelivery = _accepted("paid")
	var job_id: StringName = job.job_id
	_kill(NpcPopulationQueries.person_for(job.npc_id))
	_morning(3)
	_roundtrip(3)
	job = HomeDeliveryQueries.find(job_id)
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(job.npc_id)
	var player: Entity = _player_actor()
	DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
	var door: Entity = _door(person.home_id)
	assert_true(NpcHomeDeliveryService.knock(player, door))
	assert_eq(visit.last_visit_day, 3)
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var parcel: Entity = PackageQueries.find_live_package(job.package_id)
	(player as Node as Node3D).global_position = body.global_position + Vector3(0.0, 0.0, -1.0)
	(player as E_RigidBodyCharacter).hold_anchor.position = Vector3(0.0, 1.3, -0.5)
	(parcel as Node as Node3D).global_position = (
		body.hold_anchor.global_position - body.hold_anchor.global_basis.z * 0.35
	)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), player))
	assert_eq(
		CustomerFlowService.confirm_direct_delivery(player, body),
		PackageDeliveryCheck.Result.READY,
	)
	assert_eq(visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_lt(
		CustomerInspectionRules.roll(visit, "keep"),
		visit.definition.inspection_keep_probability,
	)
	CustomerFlowService.complete_inspection(body, visit)
	assert_eq(visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_null(PackageQueries.find_live_package(job.package_id))
	assert_true(NpcHomeDeliveryService.complete(job))
	var balance: int = WalletService.current().balance
	assert_eq(WalletService.current().operations.size(), 2)
	assert_eq(
		balance,
		visit.payment * visit.satisfaction / CustomerOutcomeService.SATISFACTION_SCALE + job.bonus,
	)
	assert_true(job.bonus_committed)
	assert_true(NpcHomeDeliveryService.complete(job))
	_world.remove_entity(player)
	_roundtrip(3)
	job = HomeDeliveryQueries.find(job_id)
	assert_true(NpcHomeDeliveryService.complete(job))
	assert_eq(WalletService.current().balance, balance)
	assert_eq(WalletService.current().operations.size(), 2)
	_kill(NpcPopulationQueries.person_for(job.npc_id))
	_morning(5)
	assert_eq(WalletService.current().balance, balance)
	assert_eq(WalletService.current().operations.size(), 2)
	assert_eq(job.status, NpcHomeDelivery.Status.DELIVERED)


func test_pending_old_fraud_claim_keeps_world_deadline_and_real_once_penalty() -> void:
	var visit: CustomerVisit = _visit("fraud")
	visit.accounting_value = 30
	visit.declaration = CustomerVisit.Declaration.TAKEN
	visit.complaint = CustomerComplaint.new()
	visit.complaint.complaint_id = &"claim/old_fraud"
	visit.complaint.customer_id = visit.customer_id
	visit.complaint.resolve_day = 2
	visit.finished = true
	_kill(NpcPopulationQueries.person_for(visit.customer_id))
	assert_false(visit.customer_dead)
	_morning(2)
	CustomerOutcomeService.resolve_complaint(visit, WalletService.current(), 2)
	assert_eq(visit.complaint.outcome, CustomerComplaint.Outcome.CONFIRMED)
	assert_eq(visit.reputation, CustomerVisit.Reputation.FRAUD)
	assert_eq(WalletService.current().balance, -60)
	CustomerOutcomeService.resolve_complaint(visit, WalletService.current(), 2)
	_morning(3)
	assert_eq(WalletService.current().balance, -60)
	assert_eq(WalletService.current().operations.size(), 1)


func test_terminal_and_door_present_absence_without_a_guessed_return_date() -> void:
	var job: NpcHomeDelivery = _accepted("visible")
	_kill(NpcPopulationQueries.person_for(job.npc_id))
	_morning(2)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	var info: TerminalDeliveryInfo = HomeDeliveryQueries.published_by_package(
		PackageQueries.ledger(),
		PackageQueries.live_states(),
		{ visit.package_id: visit },
	)[job.package_id]
	assert_eq(info.deadline_day, 0)
	assert_eq(info.status_text, "Получатель временно недоступен")
	var row: UI_TerminalButtonPackage = (
		load("res://content/ui/ui_terminal_package_line.tscn") as PackedScene
	).instantiate() as UI_TerminalButtonPackage
	add_child(row)
	row.call("_present_delivery", info, true)
	var tooltip: String = (row.get_node("%DeliveryControl") as Control).tooltip_text
	assert_true(tooltip.contains("срок после возвращения"))
	assert_false(tooltip.contains("дня 0"))
	assert_false(tooltip.contains("дня 3"))
	row.free()
	var detail: UI_TerminalPackageDetailInfo = (
		load("res://content/ui/ui_terminal_package_detail_info.tscn") as PackedScene
	).instantiate() as UI_TerminalPackageDetailInfo
	add_child(detail)
	detail.present(
		PackageHistoryService.record_for(job.package_id),
		PackageQueries.live_states()[job.package_id],
		visit,
		false,
		info,
	)
	var description: String = (detail.get_node("%RichTextLabelDescription") as RichTextLabel).text
	assert_true(description.contains("после возвращения получателя"))
	assert_false(description.contains("дня 3"))
	detail.free()
	assert_true(NpcHomeDeliveryService.status_text().contains("временно недоступен"))
	assert_same(HomeMeetingQueries.job_for_address(job.address_id), job)
	var action: DEF_NpcDoorAction = DEF_NpcDoorAction.new()
	var door: Entity = _door(job.address_id)
	var player: Entity = _player_actor()
	assert_true(action.is_available(player, door, door))
	assert_eq(action.caption_for(player, door, door), "Получатель временно недоступен")
	assert_false(NpcHomeDeliveryService.knock(player, door))


func test_night_save_captures_resumed_order_once_and_retries_same_snapshot() -> void:
	var job: NpcHomeDelivery = _accepted("night")
	_kill(NpcPopulationQueries.person_for(job.npc_id))
	_morning(2)
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	var state: C_Autosave = C_Autosave.new()
	state.path = "user://gut_npc_orders_missing/slot.pvzh"
	assert_false(
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(state.path.get_base_dir()))
	)
	session.add_component(state)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.NIGHT
	_world.add_system(S_NightSave.new())
	for attempt: int in 24:
		_world.process(0.1, "Storage")
		if not state.prepared_snapshot.is_empty():
			break
	assert_false(state.prepared_snapshot.is_empty())
	if state.prepared_snapshot.is_empty():
		return
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	assert_eq(job.status, NpcHomeDelivery.Status.ACCEPTED)
	assert_eq(visit.absence_sequence, 0)
	assert_eq(visit.next_followup_day, 4)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 4)
	var prepared: Dictionary = state.prepared_snapshot.duplicate(true)
	state.retry_remaining = 0.0
	_world.process(0.1, "Storage")
	assert_eq(state.prepared_snapshot, prepared)
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	_world.process(0.1, "Storage")
	assert_eq(state.last_error, OK)
	assert_true(DayPhaseQueries.current().night_ready)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	var restored: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	assert_eq(restored.absence_sequence, 0)
	assert_eq(restored.next_followup_day, 4)
	assert_eq(_district.home_deliveries.size(), 1)
#endregion


#region Отложенный факт и закрытый preflight
func test_old_return_fact_cannot_resume_a_new_death_episode() -> void:
	var job: NpcHomeDelivery = _accepted("stale_return")
	var person: NpcRecord = NpcPopulationQueries.person_for(job.npc_id)
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(job.visit_id)
	var planning: O_CustomerPlanning = null
	for observer: Observer in _world.observers:
		if observer is O_CustomerPlanning:
			planning = observer as O_CustomerPlanning
	assert_not_null(planning)
	planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_kill(person)
	_morning(3)
	_kill(person)
	assert_eq(visit.absence_sequence, 2)
	planning.cmd.execute()
	assert_eq(visit.absence_sequence, 2)
	assert_eq(HomeDeliveryQueries.active_deadline_day(job), 0)
	planning.command_buffer_flush_mode = Observer.FlushMode.PER_CALLBACK
	_morning(5)
	assert_eq(visit.absence_sequence, 0)
	assert_eq(visit.next_followup_day, 6)


func test_absence_marker_requires_exact_pending_person_episode_before_restore() -> void:
	var job: NpcHomeDelivery = _accepted("preflight")
	_kill(NpcPopulationQueries.person_for(job.npc_id))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for malformed: int in [-1, 2]:
		var corrupt: Dictionary = snapshot.duplicate(true)
		for actor: Dictionary in corrupt.entities:
			for component: Dictionary in actor.components:
				if component.type != (C_CustomerFlow as Script).resource_path:
					continue
				var encoded: Array = component.fields.visits
				(encoded[0] as Dictionary).fields.absence_sequence = malformed
		assert_false(WorldSnapshotService.can_restore(corrupt, _root))
		assert_eq(CustomerFlowQueries.find_visit(job.visit_id).absence_sequence, 1)
		assert_eq(WalletService.current().operations.size(), 0)
#endregion


#region Сохранённый отказ не реактивируется во время отсутствия
func test_existing_denial_followup_waits_for_living_recipient_without_erasing_reputation() -> void:
	var visit: CustomerVisit = _visit("denial")
	visit.actual = CustomerVisit.Actual.PLAYER_DENIED
	visit.reputation = CustomerVisit.Reputation.PLAYER_DENIAL
	visit.finished = true
	visit.finished_day = 1
	visit.next_followup_day = 2
	visit.followup_committed = true
	_kill(NpcPopulationQueries.person_for(visit.customer_id))
	assert_eq(CustomerFlowFixture.reactivate(CustomerFlowQueries.current(), 2), 0)
	assert_eq(visit.actual, CustomerVisit.Actual.PLAYER_DENIED)
	assert_eq(visit.reputation, CustomerVisit.Reputation.PLAYER_DENIAL)
	assert_false(CustomerFlowQueries.visit_due(visit, 2))
	assert_eq(CustomerFlowQueries.actionable_remaining(CustomerFlowQueries.current(), 2), 0)
	_morning(3)
	CustomerFlowFixture.reactivate(CustomerFlowQueries.current(), 3)
	assert_eq(visit.reputation, CustomerVisit.Reputation.PLAYER_DENIAL)
	assert_false(visit.customer_dead)
#endregion


#region RV-007 — возврат после уже выполненного планирования DAY
func test_due_counter_order_reactivates_on_actual_return_without_another_planning_fact() -> void:
	var visit: CustomerVisit = _visit("already_due")
	var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
	_kill(person)
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 3.0)
	collision.shape = shape
	blocker.add_child(collision)
	_root.add_child(blocker)
	blocker.global_position = NpcPopulationQueries.position_for(person.home_id, true) + Vector3.UP
	await get_tree().physics_frame
	_morning(3)
	assert_eq(person.death_day, 1)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	CustomerFlowService.reconcile_session(_world, session)
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	assert_eq(flow.planning_day, 3)
	assert_eq(flow.planning_phase, int(C_DayCycle.Phase.DAY))
	assert_true(visit.finished)
	blocker.free()
	await get_tree().physics_frame
	# Только native возврат. Ни scan, ни DayPhaseChanged, ни explicit reactivate не посылаются.
	assert_eq(DistrictPopulationService.return_due(_district, 3).size(), 1)
	assert_eq(visit.absence_sequence, 0)
	assert_false(visit.finished)
	assert_true(CustomerFlowQueries.visit_due(visit, 3))
	assert_eq(CustomerFlowQueries.actionable_remaining(flow, 3), 1)
	assert_eq(visit.followup_count, 0)
	assert_eq(visit.visit_count, 0)
#endregion


#region RV-007 — future Morning во время Night
func test_due_counter_return_uses_prepared_morning_day_without_advancing_night() -> void:
	var visit: CustomerVisit = _visit("future_morning", 3)
	_kill(NpcPopulationQueries.person_for(visit.customer_id))
	_morning(2)
	_return_during_night(3)
	assert_eq(DayPhaseQueries.current().day_index, 2)
	assert_eq(DayPhaseQueries.current().phase, C_DayCycle.Phase.NIGHT)
	assert_eq(visit.absence_sequence, 0)
	assert_false(visit.finished)
	assert_true(CustomerFlowQueries.visit_due(visit, 3))
	assert_eq(visit.followup_count, 0)
	assert_eq(visit.visit_count, 0)
#endregion
