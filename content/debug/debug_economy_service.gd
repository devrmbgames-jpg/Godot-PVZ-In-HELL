extends RefCounted
## Journaled manual wallet operations for developer-console testing.
class_name DebugEconomyService

const OPERATION_PREFIX: String = "debug"


static func credit(amount: int, note: String) -> DebugServiceResult:
	return _submit(MoneyOperation.Reason.DEBUG_CREDIT, amount, note)


static func debit(amount: int, note: String) -> DebugServiceResult:
	return _submit(MoneyOperation.Reason.DEBUG_DEBIT, amount, note)


static func penalty(amount: int, note: String) -> DebugServiceResult:
	return _submit(MoneyOperation.Reason.DEBUG_PENALTY, amount, note)


static func reverse_penalty(amount: int, note: String) -> DebugServiceResult:
	var wallet: C_Wallet = WalletService.current()
	var result: DebugServiceResult = DebugServiceResult.new()
	if wallet == null:
		result.message = "wallet is unavailable"
		return result

	var outstanding: int = manual_penalty_outstanding(wallet)
	if amount > outstanding:
		result.message = "amount exceeds outstanding debug penalty: %d" % outstanding
		return result
	return _submit(MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL, amount, note)


static func manual_penalty_outstanding(wallet: C_Wallet) -> int:
	if wallet == null:
		return 0

	var outstanding: int = 0
	for operation: MoneyOperation in wallet.operations:
		if operation.reason == MoneyOperation.Reason.DEBUG_PENALTY:
			outstanding += operation.amount
		elif operation.reason == MoneyOperation.Reason.DEBUG_PENALTY_REVERSAL:
			outstanding -= operation.amount
	return maxi(0, outstanding)


static func _submit(
	reason: MoneyOperation.Reason,
	amount: int,
	note: String,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if amount <= 0 or amount > WalletService.MAX_AMOUNT:
		result.message = "amount must be between 1 and %d" % WalletService.MAX_AMOUNT
		return result

	var wallet: C_Wallet = WalletService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if wallet == null or cycle == null:
		result.message = "wallet/day cycle is unavailable"
		return result

	var before_balance: int = wallet.balance
	var before_penalties: int = wallet.penalties
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = _next_operation_id(wallet, cycle.day_index, reason)
	operation.reason = reason
	operation.amount = amount
	operation.day_index = cycle.day_index
	operation.note = note.strip_edges()

	var status: WalletService.Status = WalletService.submit(operation)
	if status != WalletService.Status.COMMITTED:
		result.message = "WalletService rejected operation: %s" % _status_name(status)
		return result

	result.success = true
	result.message = "wallet operation committed"
	result.details.append("operation=%s" % String(operation.operation_id))
	result.details.append("balance=%d -> %d" % [before_balance, wallet.balance])
	result.details.append("penalties=%d -> %d" % [before_penalties, wallet.penalties])
	return result


static func _next_operation_id(
	wallet: C_Wallet,
	day_index: int,
	reason: MoneyOperation.Reason,
) -> StringName:
	var reason_name: String = String(MoneyOperation.Reason.keys()[reason]).to_lower()
	var sequence: int = 1
	while true:
		var candidate: StringName = StringName(
			"%s/%d/%s/%d" % [OPERATION_PREFIX, day_index, reason_name, sequence]
		)
		var exists: bool = false
		for operation: MoneyOperation in wallet.operations:
			if operation.operation_id == candidate:
				exists = true
				break
		if not exists:
			return candidate

		sequence += 1
	return &""


static func _status_name(status: WalletService.Status) -> String:
	var keys: Array = WalletService.Status.keys()
	return String(keys[status]) if status >= 0 and status < keys.size() else "UNKNOWN"
