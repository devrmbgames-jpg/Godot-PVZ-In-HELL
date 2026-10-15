extends Component
## Прогресс реальной утренней поставки; повторные попытки не создают дополнительные партии.
## ReceivingDeliveryService ведёт manifest/позицию, TruckCargoService — cargo receipts;
## S_Receiving ведёт retry clock, restore отдельно инвалидирует transient context.
class_name C_Receiving

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"last_started_day",
	"batch_id",
	"dispatched_batch_id",
	"cargo_batch_id",
	"cargo_receipts",
	"incoming_package_ids",
	"pending",
	"delivered_counts",
]

## День последней подготовленной партии, сохраняемый между запусками.
var last_started_day: int = 0
## Стабильный ID текущей утренней партии, включая пустую поставку.
var batch_id: String = ""
## Последняя зафиксированная отправка партии; защищает границу обратного груза от повторного
## исполнения.
var dispatched_batch_id: String = ""
## Партия зафиксированного обратного груза; пустой состав тоже фиксируется один раз.
var cargo_batch_id: String = ""
## История удаления и расчёта предметов, сохраняемая вместе с партией.
var cargo_receipts: Array[TruckCargoReceipt] = []
## Синхронная защита от повторного входа во время структурных уведомлений World.
var cargo_commit_in_progress: bool = false
## Состав партии для разгрузки: ID всех ожидаемых коробок, не ссылки на физические тела.
var incoming_package_ids: PackedStringArray = []
## Резервы полного объёма в кадре создания, до обновления physics space; не сохраняются.
var reservations: Array[AABB] = []
## Кадр временных резервов размещения.
var reservation_frame: int = -1
## Зафиксированные ещё не законченные партии; обычная поставка оставляет одну партию дня.
var pending: Array[ReceivingBatch] = []
## Количество пройденных позиций партии по дням для вывески и сохранения.
var delivered_counts: Dictionary[int, int] = { }
## Последняя попытка размещения заблокирована; используется для сообщения игроку.
var blocked: bool = false
## Остаток паузы перед повтором размещения, в gameplay-секундах.
var retry_remaining: float = 0.0
## Номер последнего физического кадра создания; запрещает две коробки в одном кадре.
var last_spawn_tick: int = -1

## Transient delivery context revision; explicit restore invalidates pre-load requests.
var context_revision: int = 0
