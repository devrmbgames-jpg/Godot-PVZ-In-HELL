extends Component
## S_OrderDelivery owns morning retries; OrderDeliveryService commits one paid delivery.
## Orders/fulfilled остаются в C_Commerce; goods/reservations являются derived caches этого World.
class_name C_OrderReceiving

## Положительное число колонок простых pickup-кандидатов; мебель использует furniture_placement.
@export var columns: int = 4
## Положительное число рядов простых pickup-кандидатов.
@export var rows: int = 3
## Положительный шаг простых pickup-кандидатов по локальным +X/+Z в метрах.
@export var spacing: Vector2 = Vector2(0.75, 0.75)
## Запас физической проверки размещения в метрах.
@export var collision_margin: float = 0.03
## OrderDeliveryService отмечает отказ последней попытки: место/prefab/recipe могут быть не готовы.
var blocked: bool = false

## NodePath от Entity зоны к маркеру мебели; '.' означает саму зону.
@export var furniture_anchor_path: NodePath = NodePath(".")
## Неизменяемая Definition ограниченных позиций/формы/опоры мебели.
@export var furniture_placement: DEF_ItemPlacement = preload(
	"res://content/domains/commerce/definitions/def_furniture_delivery_placement.tres"
)
## Gameplay seconds между выдачами/retry; S_OrderDelivery уменьшает таймер только утром.
@export_range(0.25, 10.0) var retry_seconds: float = 1.0

## S_OrderDelivery пишет остаток gameplay seconds; reset_context обнуляет, не сохраняется.
var retry_remaining: float = 0.0
## S_OrderDelivery отмечает день прохода; новый день/restore сбрасывает retry и exhausted.
var attempt_day: int = 0
## OrderDeliveryService не нашёл due заказов; System пропускает очередь до нового дня/reset.
var exhausted: bool = false
## OrderDeliveryService построил goods для этого World; reset_context инвалидирует индекс.
var identity_index_ready: bool = false
## Derived key → WeakRef cache OrderDeliveryService; не владеет предметами, reset_context очищает.
var goods: Dictionary[String, WeakRef] = { }
## World-space AABB резервы OrderDeliveryService до обновления physics space, не сохраняются.
var reservations: Array[AABB] = []
## Engine physics frame набора reservations; новый frame/restore очищает резервы.
var reservation_frame: int = -1

## S_OrderDelivery coalesces one queued fulfillment; execution/reset clears it, never persisted.
var delivery_queued: bool = false

## S_OrderDelivery increments per ticket; reset_context increments to invalidate old queued work.
var delivery_revision: int = 0
