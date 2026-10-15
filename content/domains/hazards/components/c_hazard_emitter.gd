@tool
extends Component
## Данные одноразового/повторного производителя автономной опасности.
class_name C_HazardEmitter

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["fired", "sequence"]

## Автономная сцена опасности с корнем E_Hazard.
@export var hazard_scene: PackedScene = null
## Разрешает только один принятый запрос этого производителя.
@export var one_shot: bool = true
## HazardEmitter фиксирует до submit; успех доставки не гарантирует создание prefab.
var fired: bool = false
## HazardEmitter увеличивает для submit и откатывает при его отказе; счётчик сохраняется.
var sequence: int = 0
