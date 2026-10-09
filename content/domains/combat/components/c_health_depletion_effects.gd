extends Component
## Авторский план однократных игровых и визуальных эффектов истощения здоровья.
class_name C_HealthDepletionEffects

## Игровые сцены создаются отдельно, без копирования компонентов источника.
@export var spawns: Array[DEF_DepletionSpawn] = []
## Необязательная сцена представления, передаваемая через HealthDepletionEvent.
@export var vfx: PackedScene = null
## Необязательный звук представления, отдельно от игровых сцен.
@export var sfx: AudioStream = null
## Защита повтора, фиксируемая до callback и создания сцен.
var committed: bool = false
