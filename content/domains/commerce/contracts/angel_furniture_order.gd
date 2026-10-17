extends Resource
## Закрытая оплаченная запись одного терминала: чек и обещание без отдельной копии очереди.
class_name AngelFurnitureOrder

const SAVE_FIELDS: Array[String] = [
	"operation_id",
	"terminal_id",
	"receiving_id",
	"receiving_hint",
	"item",
	"quantity",
	"total_price",
	"ordered_day",
	"ready_day",
	"output_id",
	"paid",
	"issued",
	"received",
	"issued_position",
]

## Устойчивый ID одновременно собственного чека и денежной операции.
@export var operation_id: StringName = &""
## Исторический ID владельца обещания; не live Entity ссылка.
@export var terminal_id: String = ""
## Домашняя площадка, выбранная до оплаты; ПВЗ не может её подменять.
@export var receiving_id: StringName = &""
## Замороженная подсказка игроку о месте выдачи.
@export var receiving_hint: String = ""
## Принятая immutable Definition мебели.
@export var item: DEF_InventoryItem
## Одна физическая единица на оплаченный заказ.
@export var quantity: int = 1
## Полная оплаченная цена, не пересчитываемая по нынешнему каталогу.
@export var total_price: int = 0
## Игровой день оплаты.
@export var ordered_day: int = 1
## Обещанное утро ordered_day + 1, включая просроченное ожидание места.
@export var ready_day: int = 2
## Единственный устойчивый ID world-owned тела.
@export var output_id: String = ""
## Кошелёк уже подтвердил покупку; частичный чек не является допустимым снимком.
@export var paid: bool = false
## Факт публикации физического тела; исчезновение тела его не отменяет.
@export var issued: bool = false
## Тело забрали, переместили с места выдачи либо оно завершило жизнь в мире.
@export var received: bool = false
## Исходная мировая точка выдачи для наблюдения переноса, не физическая authority.
@export var issued_position: Vector3 = Vector3.ZERO
