extends GutTest
## Проверяет однократные денежные операции, авторские ставки и независимые дневные итоги.


#region Операции, ставки и однократный расчёт
func _operation(id: StringName, reason: MoneyOperation.Reason, amount: int, day: int = 1) -> MoneyOperation:
	var operation: MoneyOperation = MoneyOperation.new()
	operation.operation_id = id
	operation.reason = reason
	operation.amount = amount
	operation.day_index = day
	return operation


## Записанная операция независима от исходного Resource; повтор ID не удваивает выплату.
func test_payment_is_committed_once_and_copied() -> void:
	var wallet: C_Wallet = C_Wallet.new()
	var operation: MoneyOperation = _operation(&"delivery/1", MoneyOperation.Reason.PAYMENT, 100)
	assert_eq(WalletService.apply(wallet, operation, 1), WalletService.Status.COMMITTED)
	assert_eq(WalletService.apply(wallet, operation, 1), WalletService.Status.DUPLICATE)
	operation.amount = 200
	assert_eq(wallet.balance, 100)
	assert_eq(wallet.operations[0].amount, 100)
	assert_eq(WalletService.apply(wallet, operation, 1), WalletService.Status.CONFLICT)


## Проверка средств и списание атомарны; отказ допускает повтор после пополнения.
func test_purchase_check_and_debit_are_atomic_and_failed_request_can_retry() -> void:
	var wallet: C_Wallet = C_Wallet.new()
	wallet.balance = 10
	var purchase: MoneyOperation = _operation(&"purchase/1", MoneyOperation.Reason.PURCHASE, 20)
	assert_eq(WalletService.apply(wallet, purchase, 1), WalletService.Status.INSUFFICIENT_FUNDS)
	assert_eq(wallet.balance, 10)
	assert_eq(wallet.operations.size(), 0)
	WalletService.apply(wallet, _operation(&"payment", MoneyOperation.Reason.PAYMENT, 10), 1)
	assert_eq(WalletService.apply(wallet, purchase, 1), WalletService.Status.COMMITTED)
	assert_eq(wallet.balance, 0)


## Авторские ставки разных исходов создают долг с правильной классификацией штрафа.
func test_package_rates_debt_and_penalty_classification() -> void:
	var reasons: Array[MoneyOperation.Reason] = [
		MoneyOperation.Reason.VOLUNTARY_BUYOUT,
		MoneyOperation.Reason.LOST,
		MoneyOperation.Reason.PLAYER_REFUSAL,
		MoneyOperation.Reason.CONFIRMED_FRAUD,
		MoneyOperation.Reason.MISSED_REGISTRATION,
	]

	var expected: Array[int] = [100, 120, 150, 200, 300]
	for index: int in reasons.size():
		var wallet: C_Wallet = C_Wallet.new()
		var operation: MoneyOperation = WalletService.package_settlement(wallet, &"shipment/outcome", reasons[index], 100, 1)
		assert_eq(operation.amount, expected[index])
		assert_eq(WalletService.apply(wallet, operation, 1), WalletService.Status.COMMITTED)
		assert_eq(wallet.balance, -expected[index])
		assert_eq(wallet.penalties, 0 if index == 0 else expected[index])


## Утренний возврат не повторяет прежний расчёт коробки даже с новым operation_id.
func test_return_next_morning_cannot_repeat_settlement() -> void:
	var wallet: C_Wallet = C_Wallet.new()
	var operation: MoneyOperation = WalletService.package_settlement(wallet, &"outcome/1", MoneyOperation.Reason.LOST, 100, 1)
	WalletService.apply(wallet, operation, 1)
	operation.operation_id = &"return/retry"
	assert_eq(WalletService.apply(wallet, operation, 2), WalletService.Status.DUPLICATE)
	operation.reason = MoneyOperation.Reason.CONFIRMED_FRAUD
	assert_eq(WalletService.apply(wallet, operation, 2), WalletService.Status.CONFLICT)
	assert_eq(wallet.balance, -120)


## Дневные итоги сохраняют общий баланс и однократное завершение дня.
func test_daily_totals_and_completed_days_do_not_reset_wallet() -> void:
	var wallet: C_Wallet = C_Wallet.new()
	var cycle: C_DayCycle = C_DayCycle.new()
	WalletService.apply(wallet, _operation(&"day1", MoneyOperation.Reason.PAYMENT, 100), 1)
	cycle.phase = C_DayCycle.Phase.EVENING
	WalletService.sync_day(wallet, cycle)
	WalletService.sync_day(wallet, cycle)
	assert_eq(wallet.completed_days, 1)
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.MORNING
	WalletService.sync_day(wallet, cycle)
	WalletService.apply(wallet, _operation(&"day2", MoneyOperation.Reason.PURCHASE, 20, 2), 2)
	assert_eq(wallet.balance, 80)
	assert_eq(wallet.daily_results[0].income, 100)
	assert_eq(wallet.daily_results[0].closing_balance, 100)
	assert_eq(wallet.daily_results[1].spending, 20)
	assert_eq(wallet.daily_results[1].income, 0)

	var saved: C_Wallet = WalletService.snapshot(wallet)
	saved.operations[0].amount = 999
	assert_eq(wallet.operations[0].amount, 100)
	assert_eq(WalletService.apply(saved, _operation(&"day2", MoneyOperation.Reason.PURCHASE, 20, 2), 2), WalletService.Status.DUPLICATE)


## Недопустимая сумма и устаревший день не меняют баланс или журнал.
func test_invalid_and_stale_operations_do_not_mutate_state() -> void:
	var wallet: C_Wallet = C_Wallet.new()
	assert_eq(WalletService.apply(wallet, _operation(&"bad", MoneyOperation.Reason.PAYMENT, -1), 1), WalletService.Status.INVALID)
	assert_eq(WalletService.apply(wallet, _operation(&"stale", MoneyOperation.Reason.PAYMENT, 10), 2), WalletService.Status.INVALID)
	assert_eq(wallet.balance, 0)
	assert_true(wallet.operations.is_empty())


## Настраиваемый процент расчёта округляет денежную сумму по общей политике.
func test_authored_rate_and_rounding() -> void:
	var wallet: C_Wallet = C_Wallet.new()
	wallet.policy = DEF_Economy.new()
	wallet.policy.lost_percent = 125
	var operation: MoneyOperation = WalletService.package_settlement(wallet, &"rounding", MoneyOperation.Reason.LOST, 3, 1)
	assert_eq(operation.amount, 4)

#endregion
