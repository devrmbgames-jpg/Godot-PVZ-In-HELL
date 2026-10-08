extends Component
## Сессионная очередь неразмещённого лута и журнал однократно подготовленных партий.
class_name C_LootDrops

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["placement", "pending", "committed_batches"]

#region Постоянные и временные данные
## Авторские позиции и ограничение стоимости проверки.
@export var placement: DEF_ItemPlacement = preload("res://content/definitions/gameplay/def_item_placement_default.tres")
## Остаток фиксированных партий; удаление источника его не удаляет.
var pending: Array[PendingLootDrop] = []
## Зафиксированные партии, включая полностью размещённые или употреблённые предметы.
var committed_batches: Dictionary[String, bool] = {}
## Временная пауза между повторами; после загрузки начинается заново.
var retry_remaining: float = 0.0
## One deferred retry is outstanding for this aggregate; transient, never persisted.
var retry_queued: bool = false
## Transient retry ticket revision; explicit restore invalidates outstanding requests.
var retry_revision: int = 0
## Резервы новых предметов текущего физического кадра, пока space ещё не обновился.
var reservations: Array[AABB] = []
## Номер кадра временных резервов; не сохраняется.
var reservation_frame: int = -1
#endregion
