extends Component
## CommerceService создаёт чеки/заказы; OrderDeliveryService отмечает физическое исполнение.
## Records hold no live items; C_OrderReceiving owns delivery queue/guards.
class_name C_Commerce

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"receipts",
	"buyback_sales",
	"crafting_batches",
	"pending_deliveries",
	"next_request",
]

## Журнал оплаченных покупок; ID защищают от повторного списания.
@export var receipts: Array[PurchaseReceipt] = []
## История принятых продаж контейнеров; переживает отсутствие NPC и удаление самой точки.
## BuybackTradeService фиксирует receipt и деньги одной синхронной операцией.
@export var buyback_sales: Array[BuybackSale] = []
## Принятые партии мастерских, включая подарки/льготу и исполненные результаты.
## CraftingService пишет приём/выдачу; удаление точки не уничтожает обязательство.
@export var crafting_batches: Array[CraftingBatch] = []
## Оплаченные доставки, включая уже исполненные для защиты от повтора.
@export var pending_deliveries: Array[PendingDelivery] = []
## Неизменяемый runtime ассортимент терминала; ассортимент торговца задаёт отдельный Profile.
@export var catalog: Array[DEF_InventoryItem] = [
	preload("res://content/domains/inventory/definitions/def_item_food.tres"),
	preload("res://content/domains/inventory/definitions/def_item_med.tres"),
	preload("res://content/domains/inventory/definitions/def_item_bubble_wrap.tres"),
	preload("res://content/domains/inventory/definitions/def_item_scanner.tres"),
	preload("res://content/domains/inventory/definitions/def_item_marker.tres"),
]
## Сохраняемый счётчик ID торговых запросов.
@export var next_request: int = 0
## CommerceService удерживает transient guard при синхронных оплате/выдаче, не сохраняется.
var transaction_in_progress: bool = false
