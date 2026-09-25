extends Component
## Reusable one-shot/repeatable producer of an autonomous hazard scene.
class_name C_HazardEmitter

@export var hazard_scene: PackedScene = null
@export var one_shot: bool = true
## Runtime producer guard/counter; persist these alongside origin identity when saving.
var fired: bool = false
var sequence: int = 0
