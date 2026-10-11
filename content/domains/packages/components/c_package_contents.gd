extends Component
## Признак однократного извлечения; созданные предметы владеют своим состоянием и физикой.
class_name C_PackageContents

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["released", "selected_item"]

## Committed immutable order definition; null retains the package's authored legacy contents.
@export var selected_item: DEF_InventoryItem = null

## Содержимое уже извлечено; повторное открытие или разрушение не создаёт его снова.
@export var released: bool = false
