extends Component
## Сетка физической выдачи заказанных товаров и состояние блокировки места.
class_name C_OrderReceiving

## Количество колонок кандидатов размещения.
@export var columns: int = 4
## Количество рядов кандидатов размещения.
@export var rows: int = 3
## Шаг между кандидатами по локальным осям в метрах.
@export var spacing: Vector2 = Vector2(0.75, 0.75)
## Запас физической проверки размещения в метрах.
@export var collision_margin: float = 0.03
## Последняя попытка доставки не нашла свободного места.
var blocked: bool = false

## Путь к авторскому маркеру мебели; уровень задаёт его через экспортируемую ссылку.
@export var furniture_anchor_path: NodePath = NodePath(".")
## Ограниченные позиции и проверки полной формы/опоры для мебели.
@export var furniture_placement: DEF_ItemPlacement = preload("res://content/domains/commerce/definitions/def_furniture_delivery_placement.tres")
## Пауза между выдачами и повторными попытками занятой площадки.
@export_range(0.25, 10.0) var retry_seconds: float = 1.0

## Остаток паузы; производный контекст, не сохраняется.
var retry_remaining: float = 0.0
## День текущего прохода очереди; новое утро снимает паузу.
var attempt_day: int = 0
## Все готовые заказы проверены; новые покупки назначаются только на следующее утро.
var exhausted: bool = false
## Индекс физических заказов собран для текущего World.
var identity_index_ready: bool = false
## Производные слабые ссылки физических заказов, без владения предметами.
var goods: Dictionary[String, WeakRef] = {}
## Зарезервированные объёмы до обновления physics space.
var reservations: Array[AABB] = []
## Физический кадр текущего набора резервов.
var reservation_frame: int = -1

## One scheduled fulfillment is queued for this live aggregate; never persisted.
var delivery_queued: bool = false

## Transient fulfillment ticket revision; explicit restore invalidates outstanding requests.
var delivery_revision: int = 0
