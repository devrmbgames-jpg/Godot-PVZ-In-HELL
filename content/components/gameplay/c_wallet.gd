extends Component
## Session-owned persistent authority. Only WalletService writes runtime state.
class_name C_Wallet

@export var balance: int = 0
@export var penalties: int = 0
@export var completed_days: int = 0
@export var policy: DEF_Economy = preload(
	"res://content/definitions/gameplay/economy/def_economy_default.tres"
)
@export var operations: Array[MoneyOperation] = []
@export var daily_results: Array[DailyMoneyResult] = []
