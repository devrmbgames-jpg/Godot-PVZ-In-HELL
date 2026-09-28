extends GameDefinition
## Every nonempty predicate must match the same concrete item.
class_name DEF_AccessRequirement

@export var required_item_id: StringName = &""
@export var required_tags: Array[StringName] = []
## Consumes one concrete item, never an implicit inventory stack quantity.
@export var consume_item: bool = false
