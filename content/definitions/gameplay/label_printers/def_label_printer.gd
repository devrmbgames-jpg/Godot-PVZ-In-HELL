@tool
extends GameDefinition
## Авторские размеры и содержимое печатной этикетки; ресурс не выполняет печать.
class_name DEF_LabelPrinter

## Ширина этикетки в миллиметрах.
@export var label_width_mm: float = 60.0
## Высота этикетки в миллиметрах.
@export var label_height_mm: float = 40.0
## Включать авторское описание в печатное содержимое.
@export var include_description: bool = false
