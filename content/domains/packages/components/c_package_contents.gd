extends Component
## Признак однократного извлечения; созданные предметы владеют своим состоянием и физикой.
class_name C_PackageContents

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["released"]

## Содержимое уже извлечено; повторное открытие или разрушение не создаёт его снова.
@export var released: bool = false
