@tool
extends Component
## Дневной прайс физической точки; общий C_Commerce хранит историю оплаченных продаж.
class_name C_Buyback

## Закрытый durable контракт; profile остаётся авторским входом native сцены.
const SAVE_FIELDS: Array[String] = [
	"profile",
	"price_day",
	"price_seed",
	"supply_batch_id",
	"source_package_ids",
	"premium_item_keys",
	"premium_spent_keys",
	"prices",
]

## Неизменяемая политика точки и личности; не дублирует roster или purchase-каталог.
@export var profile: DEF_BuybackProfile = null
## День подтверждённого прайса; ноль означает, что текущая поставка ещё не подтверждена.
@export var price_day: int = 0
## Seed утреннего прайса; позднее оценённые типы используют тот же выбор.
@export var price_seed: int = 0
## ID фактически завершённой BASE_SUPPLY, по которой выбран спрос.
@export var supply_batch_id: String = ""
## Зафиксированные реально поступившие package IDs, не скрытый план следующего груза.
@export var source_package_ids: PackedStringArray = []
## Один-два разных допустимых типа по 150%; формируются только из реальной поставки.
@export var premium_item_keys: PackedStringArray = []
## Израсходованные premium единицы текущего утра; повторная жизнь продавца не очищает их.
@export var premium_spent_keys: PackedStringArray = []
## Обычные цены текущего прайса; повтор UI/restore не выбирает цену заново.
@export var prices: Array[BuybackItemPrice] = []
## Синхронная защита подтверждения/удаления; snapshot обязан дождаться её завершения.
var transaction_in_progress: bool = false
