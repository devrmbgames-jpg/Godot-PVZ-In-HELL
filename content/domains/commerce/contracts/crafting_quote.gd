extends RefCounted
## Ephemeral предложение всей партии; UI не владеет расходом, grace или распознаванием.
class_name CraftingQuote

## Weak endpoint перечитывается перед подтверждением, закрытие UI ничего не передаёт.
var container_reference: WeakRef
## Точная incarnation authored компонента.
var state: C_Crafting
## Выделенный общий commerce ID, одно явное подтверждение.
var operation_id: StringName = &""
## Календарный день наблюдаемого состава.
var day_index: int = 0
## Исторический подписанный состав, день, точка и состояние льготы.
var signature: String = ""
## Отказ целой передачи, например занятая партия или предмет в руках.
var reason: String = ""
## Все фактически передаваемые стеки, включая потенциальные подарки.
var inputs: Array[CraftingInput] = []
