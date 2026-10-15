@tool
extends GameDefinition
## Авторские ключи уведомлений общего атрибута.
class_name DEF_Attribute

## Ключ поля в payload property_changed при записи base; имя сигнала не меняется.
@export var key_base: StringName = &"base"
## Ключ поля в payload property_changed при записи value.
@export var key_value: StringName = &"value"
## Ключ поля в payload property_changed при записи current.
@export var key_current: StringName = &"current"

## Разрешает уведомления setter; значение definition должно быть задано заранее.
@export var has_emit_changes_enabled: bool = true
