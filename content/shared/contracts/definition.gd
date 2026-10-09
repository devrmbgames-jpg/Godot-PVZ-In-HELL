@tool
extends Resource
## Основа авторских игровых ресурсов с устойчивым ключом.
class_name GameDefinition

## Устойчивый авторский ID определения для учёта и ссылок.
@export var key: StringName = &""
