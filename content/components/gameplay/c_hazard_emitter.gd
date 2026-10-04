extends Component
## Данные одноразового/повторного производителя автономной опасности.
class_name C_HazardEmitter

## Автономная сцена опасности с корнем E_Hazard.
@export var hazard_scene: PackedScene = null
## Разрешает только один принятый запрос этого производителя.
@export var one_shot: bool = true
## Защита уже принятого запроса; сохраняется вместе с ID производителя.
var fired: bool = false
## Сохраняемый счётчик ID принятых запросов производителя.
var sequence: int = 0
