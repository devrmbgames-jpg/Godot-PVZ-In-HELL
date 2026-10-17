extends Resource
## Одно сохраняемое право на выручку за точный физический стек, без Node-ссылок.
class_name BuybackSaleItem

## Точный durable контракт; отсутствующие поля не заменяются значениями по умолчанию.
const SAVE_FIELDS: Array[String] = [
	"entity_id",
	"definition",
	"quantity",
	"premium_quantity",
	"amount",
	"source_package_id",
	"source_history_id",
	"removed",
]

## Entity.id фактически принятого стека; duplicate не принимает другой экземпляр.
@export var entity_id: String = ""
## Неизменяемое определение проданного типа.
@export var definition: DEF_InventoryItem = null
## Фактически согласованное количество единиц стека.
@export var quantity: int = 0
## Количество единиц по повышенному спросу; не больше одного на тип за утро.
@export var premium_quantity: int = 0
## Полная согласованная выручка за стек, включая premium и обычные единицы.
@export var amount: int = 0
## Источник извлечённого содержимого; пустой для обычного имущества.
@export var source_package_id: String = ""
## Неизменяемая история исходной посылки; продажа не меняет её получателя или actual.
@export var source_history_id: String = ""
## Сначала записывается право на выручку, затем штатный lifecycle удаляет физический стек.
@export var removed: bool = false
