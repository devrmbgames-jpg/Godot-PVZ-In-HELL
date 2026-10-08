extends GameDefinition
## Все заданные условия должны выполняться для одного конкретного предмета.
class_name DEF_AccessRequirement

## Точный item_id, если задан; пустое значение не ограничивает ID.
@export var required_item_id: StringName = &""
## Все перечисленные признаки должны присутствовать на том же подходящем предмете.
@export var required_tags: Array[StringName] = []
## Расходует один конкретный физический предмет, а не неявную единицу стека инвентаря.
@export var consume_item: bool = false
