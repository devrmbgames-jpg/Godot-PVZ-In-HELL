@tool
extends Component
## Собственная история терминала Ангела; ПВЗ не владеет ни одним из этих заказов.
class_name C_AngelOrders

const SAVE_FIELDS: Array[String] = ["profile", "orders", "next_request"]

## Неизменяемый авторский каталог и идентичность домашней площадки.
@export var profile: DEF_AngelFurnitureShop
## Оплаченные обещания и их отдельные факты физической выдачи/получения.
@export var orders: Array[AngelFurnitureOrder] = []
## Последовательность собственных запросов; отменённые предложения могут оставлять пропуски.
@export var next_request: int = 1
## Синхронный commit блокирует повторный вход и снимки посреди публикации тела.
var transaction_in_progress: bool = false
