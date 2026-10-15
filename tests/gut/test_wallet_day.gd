extends GutTest
## Exercises event-owned wallet days, queued lifetime checks and operation-free bootstrap.

var _world: World
var _session: Entity
var _wallet: C_Wallet
var _cycle: C_DayCycle
var _observer: O_WalletDay


## Counts actual calendar callbacks; bootstrap must not manufacture one.
class WalletObserverSpy extends O_WalletDay:
	## Committed calendar inputs received by the real wallet owner.
	var phase_events: int = 0


	func _on_phase(event: Variant, session: Entity, payload: Variant = null) -> void:
		phase_events += 1
		super._on_phase(event, session, payload)


#region Isolated real owner composition
func before_each() -> void:
	_observer = null
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [C_Wallet.new(), C_DayCycle.new()]
	_world.add_entity(_session)
	_wallet = _session.get_component(C_Wallet) as C_Wallet
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_wallet.balance = 250


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _install(manual: bool = false) -> void:
	_observer = O_WalletDay.new()
	if manual:
		_observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(_observer)


func _publish(phase: C_DayCycle.Phase) -> void:
	_cycle.phase = phase
	_world.emit_event(DayPhaseChanged.EVENT, _session, DayPhaseChanged.from_cycle(_cycle))


func _payment() -> MoneyOperation:
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = &"wallet_day/payment"
	operation.reason = MoneyOperation.Reason.PAYMENT
	operation.day_index = 1
	operation.amount = 100
	return operation
#endregion


#region Bootstrap and financial idempotency
## A current day exists without a single payment, including observer installation after capability.
func test_operation_free_day_bootstraps_without_completing_a_shift() -> void:
	_install()
	assert_eq(_wallet.daily_results.size(), 1)
	assert_eq(_wallet.daily_results[0].day_index, 1)
	assert_eq(_wallet.daily_results[0].closing_balance, 250)
	assert_false(_wallet.daily_results[0].shift_completed)
	assert_eq(_wallet.completed_days, 0)
	assert_eq(_wallet.operations.size(), 0)


## Receiving the first operation before or after bootstrap produces exactly the same aggregate.
func test_payment_order_relative_to_explicit_bootstrap_has_identical_totals() -> void:
	var before: C_Wallet = C_Wallet.new()
	var after: C_Wallet = C_Wallet.new()
	before.balance = 250
	after.balance = 250
	assert_eq(WalletService.apply(before, _payment(), 1), WalletService.Status.COMMITTED)
	WalletService.sync_day(before, _cycle)
	WalletService.sync_day(after, _cycle)
	assert_eq(WalletService.apply(after, _payment(), 1), WalletService.Status.COMMITTED)
	assert_eq(SaveDataCodec.component_data(before), SaveDataCodec.component_data(after))


## Replay and an explicit ready/restore retry cannot count Evening and Night as two shifts.
func test_evening_night_and_repeated_initialization_complete_once() -> void:
	_install()
	assert_eq(WalletService.apply(_wallet, _payment(), 1), WalletService.Status.COMMITTED)
	_publish(C_DayCycle.Phase.DAY)
	assert_eq(_wallet.completed_days, 0)
	_publish(C_DayCycle.Phase.EVENING)
	_publish(C_DayCycle.Phase.EVENING)
	_publish(C_DayCycle.Phase.NIGHT)
	WalletService.sync_day(_wallet, _cycle)
	assert_eq(_wallet.completed_days, 1)
	assert_eq(_wallet.daily_results.size(), 1)
	assert_true(_wallet.daily_results[0].shift_completed)
	assert_eq(_wallet.balance, 350)
	assert_eq(_wallet.daily_results[0].income, 100)
	assert_eq(_wallet.daily_results[0].spending, 0)
	assert_eq(_wallet.penalties, 0)
	assert_eq(_wallet.operations.size(), 1)


## Morning creates its own closing balance even when that new day has no operations.
func test_next_morning_has_a_separate_result_without_resetting_the_previous_day() -> void:
	_install()
	_publish(C_DayCycle.Phase.EVENING)
	_cycle.day_index = 2
	_publish(C_DayCycle.Phase.MORNING)
	assert_eq(_wallet.daily_results.size(), 2)
	assert_eq(_wallet.daily_results[0].day_index, 1)
	assert_true(_wallet.daily_results[0].shift_completed)
	assert_eq(_wallet.daily_results[1].day_index, 2)
	assert_eq(_wallet.daily_results[1].closing_balance, 250)
	assert_false(_wallet.daily_results[1].shift_completed)
	assert_eq(_wallet.completed_days, 1)
	assert_eq(_wallet.balance, 250)


## Reappearing capabilities preserve restored results instead of resetting them to defaults.
func test_materialized_evening_and_night_wallets_preserve_restored_totals() -> void:
	for phase: C_DayCycle.Phase in [C_DayCycle.Phase.EVENING, C_DayCycle.Phase.NIGHT]:
		var wallet: C_Wallet = C_Wallet.new()
		var cycle: C_DayCycle = C_DayCycle.new()
		cycle.phase = phase
		wallet.balance = -20
		WalletService.sync_day(wallet, cycle)
		wallet.daily_results[0].income = 80
		wallet.daily_results[0].spending = 100
		var saved: Dictionary = SaveDataCodec.component_data(wallet)
		var restored: C_Wallet = C_Wallet.new()
		assert_true(SaveDataCodec.apply_fields(restored, saved.fields as Dictionary))
		if _observer == null:
			_install()
		_session.remove_component(C_Wallet)
		_session.remove_component(C_DayCycle)
		_session.add_component(cycle)
		_session.add_component(restored)
		WalletService.sync_day(restored, cycle)
		assert_eq(SaveDataCodec.component_data(restored), saved)
		assert_eq(restored.completed_days, 1)


## A newly added wallet receives a discrete on_match reaction, without a calendar publication.
func test_late_wallet_capability_prepares_at_its_structural_boundary() -> void:
	_session.remove_component(C_Wallet)
	_install()
	var late_wallet: C_Wallet = C_Wallet.new()
	late_wallet.balance = 70
	_session.add_component(late_wallet)
	assert_eq(late_wallet.daily_results.size(), 1)
	assert_eq(late_wallet.daily_results[0].closing_balance, 70)


## Customers reconciliation cannot enter the wallet's calendar consumer.
func test_customer_bootstrap_does_not_invoke_wallet_calendar_reaction() -> void:
	var spy: WalletObserverSpy = WalletObserverSpy.new()
	_world.add_observer(spy)
	_world.add_observer(O_CustomerPlanning.new())
	_session.add_component(C_CustomerFlow.new())
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	assert_true(request.completed)
	assert_eq(spy.phase_events, 0)
	assert_eq(_wallet.daily_results.size(), 1)
	assert_eq(_wallet.completed_days, 0)
#endregion


#region Queued fact boundaries
## Manual and per-callback dispatch produce the same value graph once the boundary flushes.
func test_manual_flush_is_pending_until_commit_and_matches_immediate_dispatch() -> void:
	_install(true)
	assert_eq(_wallet.daily_results.size(), 0)
	_world.flush_command_buffers()
	_publish(C_DayCycle.Phase.EVENING)
	assert_eq(_wallet.completed_days, 0)
	_world.flush_command_buffers()
	var immediate: C_Wallet = C_Wallet.new()
	immediate.balance = 250
	WalletService.sync_day(immediate, _cycle)
	assert_eq(SaveDataCodec.component_data(_wallet), SaveDataCodec.component_data(immediate))
	_publish(C_DayCycle.Phase.NIGHT)
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 1)


## Stale Evening facts cannot complete the next day's fresh wallet result.
func test_stale_day_and_phase_are_rejected_before_mutation() -> void:
	_install(true)
	_world.flush_command_buffers()
	_publish(C_DayCycle.Phase.EVENING)
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.MORNING
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 0)
	assert_eq(_wallet.daily_results.size(), 1)
	_publish(C_DayCycle.Phase.EVENING)
	_cycle.phase = C_DayCycle.Phase.DAY
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 0)
	assert_eq(_wallet.daily_results.size(), 1)


## Identity replacement invalidates the queued wallet even at the same day/phase.
func test_replaced_wallet_is_not_settled_by_the_old_fact() -> void:
	_install(true)
	_world.flush_command_buffers()
	_publish(C_DayCycle.Phase.EVENING)
	_session.remove_component(C_Wallet)
	var replacement: C_Wallet = C_Wallet.new()
	_session.add_component(replacement)
	# The replacement's own capability reaction is distinct from the stale fact.
	_session.remove_component(C_Wallet)
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 0)
	assert_eq(replacement.completed_days, 0)


## Replacing the calendar invalidates queued work without losing the replacement's own bootstrap.
func test_replaced_calendar_rejects_old_fact_and_reconciles_new_capability() -> void:
	_install(true)
	_world.flush_command_buffers()
	_publish(C_DayCycle.Phase.EVENING)
	_session.remove_component(C_DayCycle)
	var replacement: C_DayCycle = C_DayCycle.new()
	_session.add_component(replacement)
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 0)
	assert_false(_wallet.daily_results[0].shift_completed)


## Global World replacement is a real async boundary even while the old World remains alive.
func test_world_replacement_cannot_commit_old_wallet_work() -> void:
	_install(true)
	_world.flush_command_buffers()
	_publish(C_DayCycle.Phase.EVENING)
	var replacement: World = World.new()
	add_child(replacement)
	ECS.world = replacement
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 0)
	ECS.world = _world
	replacement.purge(false)
	replacement.free()


## Freed Entities are resolved weakly before calling the typed wallet operation.
func test_removed_owner_cannot_commit_queued_fact() -> void:
	_install(true)
	_world.flush_command_buffers()
	_publish(C_DayCycle.Phase.EVENING)
	_world.remove_entity(_session)
	_session.free()
	_world.flush_command_buffers()
	assert_eq(_wallet.completed_days, 0)


## Repeated World.process calls have no wallet work to run; only the real phase fact reconciles.
func test_scheduled_frames_do_not_poll_wallet_day_state() -> void:
	_install()
	_cycle.phase = C_DayCycle.Phase.EVENING
	for step: int in 3:
		_world.process(0.1)
	assert_eq(_wallet.completed_days, 0)
	_world.emit_event(DayPhaseChanged.EVENT, _session, DayPhaseChanged.from_cycle(_cycle))
	assert_eq(_wallet.completed_days, 1)
#endregion


#region Real calendar producer integration
## Real committed phase transitions produce the same shift count under deferred Observer dispatch.
func test_real_day_phase_owner_drives_wallet_after_each_declared_flush() -> void:
	_install(true)
	var owner: S_DayPhase = S_DayPhase.new()
	owner.group = "calendar"
	_world.add_system(owner)
	_cycle.require_finished_customers = false
	_cycle.require_empty_customer_room = false
	_cycle.require_all_planned_arrivals = false
	_cycle.minimum_shift_seconds = 0.0
	assert_true(CommandBufferBarrier.drain_pending(_world))
	for kind: DayTransitionRequest.Kind in [
		DayTransitionRequest.Kind.START_SHIFT,
		DayTransitionRequest.Kind.FINISH_SHIFT,
		DayTransitionRequest.Kind.SLEEP,
	]:
		var request: DayTransitionRequest = DayTransitionRequest.new()
		request.kind = kind
		request.expected_day = _cycle.day_index
		request.expected_phase = _cycle.phase
		assert_true(DayPhaseService.submit(request))
		_world.process(0.0, "calendar")
		assert_true(CommandBufferBarrier.drain_pending(_world))
		assert_eq(_wallet.completed_days, 0 if _cycle.phase == C_DayCycle.Phase.DAY else 1)
	assert_eq(_wallet.daily_results.size(), 1)
	assert_true(_wallet.daily_results[0].shift_completed)
#endregion
