extends Component
## Вместимость и transient guards владельца; inventory операции пишут locks/correlation sequence.
## Сами стеки и их количество находятся в C_InventoryItem, владение — в R_OwnedBy.
class_name C_Inventory

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["maximum_stacks"]

## Авторский положительный лимит отдельных стеков; перенос сначала объединяет совместимые стеки.
@export_range(1, 32) var maximum_stacks: int = 8
## InventoryService удерживает до завершения use; лечение ждёт DamageResult или lifecycle cancel.
## Transient guard, не сохраняется и не означает, что эффект уже применён.
var use_in_progress: bool = false
## InventoryService/InventoryDropService удерживают при синхронном переносе/drop против reentry.
var transfer_in_progress: bool = false
## InventoryService увеличивает runtime sequence для use correlation; не durable history ID.
var use_sequence: int = 0
