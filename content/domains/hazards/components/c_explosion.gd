extends Component
## Защита однократного взрыва независимо от жизненного цикла создавшего объекта.
class_name C_Explosion

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["resolved"]

## Фиксируется до поиска целей и публикации урона для защиты вложенных вызовов.
var resolved: bool = false
