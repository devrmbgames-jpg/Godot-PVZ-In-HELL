extends Resource
## Постоянный итог дня; WalletService обновляет его при расчётах и завершении смены.
class_name DailyMoneyResult

## День, для которого собран итог.
@export var day_index: int = 1
## Сумма поступлений в целых денежных единицах.
@export var income: int = 0
## Сумма обычных расходов отдельно от штрафов.
@export var spending: int = 0
## Сумма штрафных операций дня с учётом отмен.
@export var penalties: int = 0
## Баланс при фиксации результата дня.
@export var closing_balance: int = 0
## Смена отмечена завершённой и учитывается в completed_days.
@export var shift_completed: bool = false
