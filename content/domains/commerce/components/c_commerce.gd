extends Component
## Сессионные записи торговли; runtime-изменения проходят через CommerceService.
class_name C_Commerce

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["receipts", "pending_deliveries", "next_request"]

## Журнал оплаченных покупок; ID защищают от повторного списания.
@export var receipts: Array[PurchaseReceipt] = []
## Оплаченные доставки, включая уже исполненные для защиты от повтора.
@export var pending_deliveries: Array[PendingDelivery] = []
## Авторский ассортимент заказов через терминал.
@export var catalog: Array[DEF_InventoryItem] = [preload("res://content/domains/inventory/definitions/def_item_food.tres"), preload("res://content/domains/inventory/definitions/def_item_med.tres"), preload("res://content/domains/inventory/definitions/def_item_bubble_wrap.tres")]
## Сохраняемый счётчик ID торговых запросов.
@export var next_request: int = 0
## Защита синхронного расчёта и выдачи от повторного входа.
var transaction_in_progress: bool = false
