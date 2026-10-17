extends Resource
## Согласованная партия с правом на оплату; retry использует прежние item IDs и сумму.
class_name BuybackSale

## Committed продажа обновляет представление дневного спроса после снятия transaction guard.
const EVENT: StringName = &"buyback_sale_committed"

## Точный durable контракт; отсутствующие поля не заменяются значениями по умолчанию.
const SAVE_FIELDS: Array[String] = [
	"operation_id",
	"trader_id",
	"buyer_npc_id",
	"container_id",
	"day_index",
	"supply_batch_id",
	"signature",
	"items",
	"amount",
	"settled",
]

## Уникальный commerce request ID, выделенный для одного подтверждения.
@export var operation_id: StringName = &""
## Entity.id реально подтвердившего NPC; входит в неизменяемую подпись партии.
@export var trader_id: String = ""
## Постоянная личность покупателя; история не исчезает вместе с физическим контейнером.
@export var buyer_npc_id: StringName = &""
## Сохранённый Entity.id точки, подтвердившей данную продажу.
@export var container_id: String = ""
## День принятия согласованного прайса и партии.
@export var day_index: int = 0
## Партия реальной утренней поставки; пусто только для FIXED скупки.
@export var supply_batch_id: String = ""
## Неизменяемая подпись предложенного состава и цен; конфликт ID не оплачивает другую партию.
@export var signature: String = ""
## Принятые физические стеки и их однократное удаление.
@export var items: Array[BuybackSaleItem] = []
## Общая выручка целыми денежными единицами.
@export var amount: int = 0
## Штатный кошелёк подтвердил COMMITTED/DUPLICATE; повтор не начисляет снова.
@export var settled: bool = false
