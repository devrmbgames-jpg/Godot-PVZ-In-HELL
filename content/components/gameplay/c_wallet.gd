extends Component
## Постоянный сессионный кошелёк; runtime-запись выполняет WalletService.
class_name C_Wallet

## Доступный баланс в целых денежных единицах.
@export var balance: int = 0
## Накопленная сумма штрафов с учётом явных отмен.
@export var penalties: int = 0
## Число зафиксированных завершённых смен.
@export var completed_days: int = 0
## Авторские ставки оплаты и штрафов.
@export var policy: DEF_Economy = preload(
	"res://content/definitions/gameplay/economy/def_economy_default.tres"
)
## Журнал принятых операций с устойчивыми ID.
@export var operations: Array[MoneyOperation] = []
## Накапливаемые итоги дней и однократные отметки завершённых смен.
@export var daily_results: Array[DailyMoneyResult] = []
