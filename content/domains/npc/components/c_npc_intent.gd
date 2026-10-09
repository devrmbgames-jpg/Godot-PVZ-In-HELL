extends Component
## Семантические цели NPC; живые Entity принадлежат R_NpcMoveTarget/R_NpcLookTarget.
class_name C_NpcIntent

enum LookMode { MOVEMENT, TARGET, HOLD }

## Есть назначенное намерение движения.
@export var movement_active: bool = false
## Мировая цель движения без живой Entity-связи, в метрах.
@export var move_position: Vector3 = Vector3.ZERO
## Допуск прибытия в метрах.
@export_range(0.01, 10.0) var arrival_distance: float = 0.25
## Доля предпочтительной скорости 0–1.
@export_range(0.0, 1.0) var speed_fraction: float = 1.0
## Взгляд вдоль движения, на цель либо удержание направления.
@export var look_mode: LookMode = LookMode.MOVEMENT
## Мировая точка взгляда без живой Entity-связи.
@export var look_position: Vector3 = Vector3.ZERO
## Добавка к позиции живой цели взгляда в мировых осях.
@export var look_offset: Vector3 = Vector3.ZERO
## Выключение разрешает прямое авторское движение/изолированные физические проверки.
@export var navigation_enabled: bool = true
## Добавка предпочтительной скорости для расхождения с ожидающим встречным соседом.
@export_range(0.0, 1.0) var passing_bias: float = 0.65
## Дальность проверки встречного соседа в метрах.
@export_range(0.0, 6.0) var passing_distance: float = 2.0

## Движение использует живую связь; потеря цели не возвращает прежнюю мировую позицию.
var move_uses_entity: bool = false
## Взгляд использует R_NpcLookTarget вместо сохранённой позиции.
var look_uses_entity: bool = false
## Производный факт достижения текущей цели.
var arrived: bool = false
## Последняя измеренная дистанция до цели в метрах.
var distance_to_target: float = 0.0
## NavigationServer ещё не готов для расчёта пути.
var navigation_pending: bool = false
## Маршрут недоступен при готовой навигации.
var navigation_blocked: bool = false
## Производная безопасная скорость асинхронного NavigationAgent, отдельно от физического исполнения.
var avoidance_velocity: Vector3 = Vector3.ZERO
## Физический кадр последней безопасной скорости NavigationAgent.
var avoidance_frame: int = -1
