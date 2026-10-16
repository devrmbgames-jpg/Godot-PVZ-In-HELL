extends Component
## Однократная передача содержимого реальным предметам либо его расходование native разрывом.
## PackageContentsService фиксирует released до регистрации тел; остаток хранится в C_LootDrops.
class_name C_PackageContents

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["released", "selected_item", "quantity", "packing_profile"]

## Committed immutable order definition; null retains the package's authored legacy contents.
@export var selected_item: DEF_InventoryItem = null

## Committed catalog unit count; zero is reserved for non-catalog authored contents.
@export var quantity: int = 0
## Committed native packing capacity/mass; null only for non-catalog authored contents.
@export var packing_profile: DEF_PackagePacking = null

## Содержимое уже извлечено или израсходовано разрывом; повторная материализация запрещена.
@export var released: bool = false
