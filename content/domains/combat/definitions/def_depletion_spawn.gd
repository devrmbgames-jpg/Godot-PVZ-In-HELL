extends Resource
## Авторская сцена эффекта истощения без живого владения.
class_name DEF_DepletionSpawn

## Создаваемая под World сцена с локальным смещением относительно цели.
@export var scene: PackedScene = null
## Локальная поза эффекта относительно сохранённой мировой позы цели.
@export var offset: Transform3D = Transform3D.IDENTITY
