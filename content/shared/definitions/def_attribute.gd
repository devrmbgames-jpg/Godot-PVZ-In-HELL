@tool
extends GameDefinition
## Авторские ключи уведомлений общего атрибута.
class_name DEF_Attribute


## Имя property_changed при записи base.
@export var key_base: StringName = &"base"
## Имя property_changed при записи вычисленного value.
@export var key_value: StringName = &"value"
## Имя property_changed при записи current.
@export var key_current: StringName = &"current"

## Разрешает уведомления setter; значение definition должно быть задано заранее.
@export var has_emit_changes_enabled: bool = true
