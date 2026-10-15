@tool
extends Component
## Данные стека в инвентаре или физическом pickup; владение задаёт R_OwnedBy только в инвентаре.
## InventoryService переносит/расходует единицы; InventoryDropService копирует их в новый pickup.
class_name C_InventoryItem

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["definition", "quantity"]

## Immutable авторское описание вида предмета/maximum_stack; runtime его не изменяет.
@export var definition: DEF_InventoryItem = null
## InventoryService пишет количество: живой стек содержит 1..maximum_stack, нулевой удаляется.
@export var quantity: int = 1
## InventoryService/InventoryDropService удерживают при переносе/drop: снятие связи не удаляет стек.
var transfer_in_progress: bool = false
## Transient correlation ID InventoryService; pending лечение ждёт совпавший DamageResult.
## При лечении расход только при applied_amount > 0; lifecycle отменяет pending, ID не сохраняется.
var pending_use_id: StringName = &""
