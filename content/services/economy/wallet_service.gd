extends RefCounted
## Synchronous atomic financial boundary; presentation receives detached snapshots.
class_name WalletService

enum Status { COMMITTED, DUPLICATE, INSUFFICIENT_FUNDS, INVALID, CONFLICT }
const PERCENT_BASE: int = 100
const MAX_AMOUNT: int = 1000000000


static func current() -> C_Wallet:
	if not is_instance_valid(ECS.world):
		return null
	var owner: Entity = ECS.world.query.with_all([C_DayCycle, C_Wallet]).execute_one()
	return owner.get_component(C_Wallet) as C_Wallet if owner != null else null


static func snapshot(wallet: C_Wallet) -> C_Wallet:
	return wallet.duplicate(true) as C_Wallet if wallet != null else null


static func submit(operation: MoneyOperation) -> Status:
	var cycle: C_DayCycle = DayPhaseService.current()
	var wallet: C_Wallet = current()
	if cycle == null:
		return Status.INVALID
	return apply(wallet, operation, cycle.day_index)


static func apply(wallet: C_Wallet, operation: MoneyOperation, current_day: int) -> Status:
	if wallet == null or operation == null or operation.operation_id == &"":
		return Status.INVALID
	if operation.amount < 0 or operation.amount > MAX_AMOUNT:
		return Status.INVALID
	if (
		operation.reason < MoneyOperation.Reason.PAYMENT
		or operation.reason > MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL
	):
		return Status.INVALID
	if _requires_settlement(operation.reason) and operation.settlement_id == &"":
		return Status.INVALID
	if (
		operation.reason == MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL
		and operation.amount > _debug_penalty_outstanding(wallet)
	):
		return Status.INVALID
	for previous: MoneyOperation in wallet.operations:
		var same_id: bool = previous.operation_id == operation.operation_id
		var same_settlement: bool = operation.settlement_id != &"" and previous.settlement_id == operation.settlement_id
		if same_id or same_settlement:
			if previous.reason == operation.reason and previous.amount == operation.amount and previous.day_index == operation.day_index and previous.settlement_id == operation.settlement_id:
				return Status.DUPLICATE
			return Status.CONFLICT
	if operation.day_index != current_day or current_day < 1:
		return Status.INVALID
	var credit: bool = _is_credit(operation.reason)
	if operation.reason == MoneyOperation.Reason.PURCHASE and wallet.balance < operation.amount:
		return Status.INSUFFICIENT_FUNDS
	var change: int = operation.amount if credit else -operation.amount
	if wallet.balance > MAX_AMOUNT - change or wallet.balance < -MAX_AMOUNT - change:
		return Status.INVALID
	var record: MoneyOperation = operation.duplicate(true) as MoneyOperation
	var daily: DailyMoneyResult = _day(wallet, current_day)
	wallet.balance += change
	wallet.operations.append(record)
	if operation.reason == MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL:
		wallet.penalties -= operation.amount
		daily.penalties -= operation.amount
	elif _is_penalty(operation.reason):
		wallet.penalties += operation.amount
		daily.penalties += operation.amount
	elif credit:
		daily.income += operation.amount
	else:
		daily.spending += operation.amount
	daily.closing_balance = wallet.balance
	return Status.COMMITTED


static func package_settlement(wallet: C_Wallet, outcome_id: StringName, reason: MoneyOperation.Reason, value: int, day_index: int) -> MoneyOperation:
	if wallet == null or wallet.policy == null or value < 0 or value > MAX_AMOUNT or outcome_id == &"":
		return null
	var percent: int = 0
	match reason:
		MoneyOperation.Reason.VOLUNTARY_BUYOUT: percent = wallet.policy.buyout_percent
		MoneyOperation.Reason.LOST: percent = wallet.policy.lost_percent
		MoneyOperation.Reason.PLAYER_REFUSAL: percent = wallet.policy.refusal_percent
		MoneyOperation.Reason.CONFIRMED_FRAUD: percent = wallet.policy.fraud_percent
		_: return null
	if percent < 0 or percent > 1000:
		return null
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = StringName("settlement/" + String(outcome_id))
	operation.settlement_id = outcome_id
	operation.reason = reason
	# Round fractional units upward, using integer arithmetic only.
	@warning_ignore("integer_division")
	operation.amount = (value * percent + PERCENT_BASE - 1) / PERCENT_BASE
	operation.day_index = day_index
	return operation


static func sync_day(wallet: C_Wallet, cycle: C_DayCycle) -> void:
	var daily: DailyMoneyResult = _day(wallet, cycle.day_index)
	if cycle.phase >= C_DayCycle.Phase.EVENING and not daily.shift_completed:
		daily.shift_completed = true
		wallet.completed_days += 1


static func _day(wallet: C_Wallet, day_index: int) -> DailyMoneyResult:
	for daily: DailyMoneyResult in wallet.daily_results:
		if daily.day_index == day_index:
			return daily
	var daily: DailyMoneyResult = DailyMoneyResult.new()
	daily.day_index = day_index
	daily.closing_balance = wallet.balance
	wallet.daily_results.append(daily)
	return daily



static func _requires_settlement(reason: MoneyOperation.Reason) -> bool:
	return (
		reason == MoneyOperation.Reason.VOLUNTARY_BUYOUT
		or reason == MoneyOperation.Reason.LOST
		or reason == MoneyOperation.Reason.PLAYER_REFUSAL
		or reason == MoneyOperation.Reason.CONFIRMED_FRAUD
	)


static func _is_credit(reason: MoneyOperation.Reason) -> bool:
	return (
		reason == MoneyOperation.Reason.PAYMENT
		or reason == MoneyOperation.Reason.DEBUG_CREDIT
		or reason == MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL
	)


static func _is_penalty(reason: MoneyOperation.Reason) -> bool:
	return (
		reason == MoneyOperation.Reason.LOST
		or reason == MoneyOperation.Reason.PLAYER_REFUSAL
		or reason == MoneyOperation.Reason.CONFIRMED_FRAUD
		or reason == MoneyOperation.Reason.DEBUG_PENALTY
	)


static func _debug_penalty_outstanding(wallet: C_Wallet) -> int:
	var outstanding: int = 0
	for operation: MoneyOperation in wallet.operations:
		if operation.reason == MoneyOperation.Reason.DEBUG_PENALTY:
			outstanding += operation.amount
		elif operation.reason == MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL:
			outstanding -= operation.amount
	return maxi(0, outstanding)
