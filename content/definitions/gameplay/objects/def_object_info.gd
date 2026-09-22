@tool
extends GameDefinition
class_name DEF_ObjectInfo

@export var title: StringName = &""
@export_multiline() var description: String = ""

## Иконка для привью и UI
@export var icon_preview: Texture = null
## Сцена которая будет распоковываться в мире. 
@export_file("*.tscn") var packed_scene_path: String = ""
