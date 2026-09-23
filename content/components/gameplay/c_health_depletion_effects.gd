extends Component
## Optional generic one-shot spawn plan and presentation hooks after Health depletion.
class_name C_HealthDepletionEffects

## Gameplay entries; instantiated independently without copying source components.
@export var spawns: Array[DEF_DepletionSpawn] = []
## Optional presentation data delivered by HealthDepletionEvent, separate from gameplay entries.
@export var vfx: PackedScene = null
@export var sfx: AudioStream = null
## Runtime dispatch guard; committed before callbacks or scene instantiation.
var committed: bool = false
