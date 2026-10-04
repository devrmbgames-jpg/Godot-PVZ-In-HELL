@tool
extends GameDefinition
## Авторские сведения и путь распаковываемого объекта для представления и предметных сервисов.
class_name DEF_ObjectInfo

## Авторское отображаемое название объекта.
@export var title: StringName = &""
## Авторское многострочное описание объекта.
@export_multiline() var description: String = ""

## Авторская иконка предпросмотра и UI.
@export var icon_preview: Texture = null
## Путь сцены объекта, распаковываемого в мире.
@export_file("*.tscn") var packed_scene_path: String = ""
