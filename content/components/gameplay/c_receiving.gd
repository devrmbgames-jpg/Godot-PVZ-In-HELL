extends Component
## Прогресс реальной утренней поставки; повторные попытки не создают дополнительные партии.
class_name C_Receiving

## День последней подготовленной партии, сохраняемый между запусками.
var last_started_day: int = 0
## Стабильный ID текущей утренней партии, включая пустую поставку.
var batch_id: String = ""
## Последняя зафиксированная отправка партии; защищает границу обратного груза от повторного исполнения.
var dispatched_batch_id: String = ""
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
## Остаток временной паузы перед повтором размещения, в секундах.
var retry_remaining: float = 0.0
## Номер последнего физического кадра создания; запрещает две коробки в одном кадре.
var last_spawn_tick: int = -1

## Transient delivery context revision; explicit restore invalidates pre-load requests.
var context_revision: int = 0
