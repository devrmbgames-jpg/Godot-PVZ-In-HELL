extends Component
## Данные виртуального стека; владелец определяется R_OwnedBy, применение — InventoryService.
class_name C_InventoryItem

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["definition", "quantity"]

## Авторское описание вида предмета и допустимого размера стека.
@export var definition: DEF_InventoryItem = null
## Положительное число единиц; не превышает maximum_stack определения.
@export var quantity: int = 1
## Защита синхронного переноса от повторного входа и очистки владения.
var transfer_in_progress: bool = false
## ID ожидаемого эффекта; количество расходуется только после принятого результата.
var pending_use_id: StringName = &""
