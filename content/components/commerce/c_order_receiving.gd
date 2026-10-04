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
