extends Component
## Вместимость и защита операций инвентаря; сами предметы связаны через R_OwnedBy.
class_name C_Inventory

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["maximum_stacks"]

## Максимум отдельных стеков; совместимые предметы сначала объединяются.
@export_range(1, 32) var maximum_stacks: int = 8
## Блокировка владельца до завершения эффекта использования.
var use_in_progress: bool = false
## Защита владельца на время синхронного переноса стека.
var transfer_in_progress: bool = false
## Последовательность для устойчивого ID запросов использования.
var use_sequence: int = 0
