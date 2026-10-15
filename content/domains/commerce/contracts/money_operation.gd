extends Resource
## Денежная операция с устойчивым ID производителя для повторных запросов и save/load.
## Producer заполняет request; WalletService сохраняет owned copy только при COMMITTED.
class_name MoneyOperation

enum Reason {
	PAYMENT,
	PURCHASE,
	VOLUNTARY_BUYOUT,
	LOST,
	PLAYER_REFUSAL,
	CONFIRMED_FRAUD,
	DEBUG_CREDIT,
	DEBUG_DEBIT,
	DEBUG_PENALTY,
	DEBUG_PENALTY_REVERSAL,
	## Автоматический штраф за пропущенную регистрацию к следующему утру.
	MISSED_REGISTRATION,
	## Доход от дешёвой продажи имущества в утренней машине.
	TRUCK_RESALE,
}

## Непустой устойчивый ID; повтор с той же нагрузкой не меняет баланс.
@export var operation_id: StringName = &""
## Назначение операции определяет направление расчёта и учёт штрафа.
@export var reason: Reason = Reason.PAYMENT
## Неотрицательная сумма в целых денежных единицах; направление задаёт reason.
@export var amount: int = 0
## Игровой день учёта операции, начиная с 1.
@export var day_index: int = 1
## ID результата посылки/спора; обязателен для расчётов обслуживания.
@export var settlement_id: StringName = &""
## Необязательное пояснение; не участвует в WalletService duplicate/conflict comparison.
@export var note: String = ""
