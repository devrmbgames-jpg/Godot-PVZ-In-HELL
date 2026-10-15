@tool
extends Component
## Часы периодического воздействия объёма; настройки принадлежат DEF_ToxicArea.
class_name C_ToxicArea

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["tick_elapsed"]

## Остаток GamePlay-секунд между тиками; S_ToxicArea накапливает и вычитает полные интервалы.
var tick_elapsed: float = 0.0
