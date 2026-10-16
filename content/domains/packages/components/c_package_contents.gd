extends Component
## Однократная передача содержимого реальным предметам либо его расходование native разрывом.
## PackageContentsService фиксирует released до регистрации тел; остаток хранится в C_LootDrops.
class_name C_PackageContents

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["released", "selected_item"]

## Committed immutable order definition; null retains the package's authored legacy contents.
@export var selected_item: DEF_InventoryItem = null

## Содержимое уже извлечено или израсходовано разрывом; повторная материализация запрещена.
@export var released: bool = false
