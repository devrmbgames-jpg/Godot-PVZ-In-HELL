extends Component
## Состояние управляемых игроком фаз и условий завершения смены.
class_name C_DayCycle

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["phase", "day_index", "clock", "shift_start_tick", "shift_end_tick"]

enum Phase {
	MORNING,
	DAY,
	EVENING,
	NIGHT,
}

## Текущая фаза; NIGHT удерживается до готовности следующего утра.
@export var phase: Phase = Phase.MORNING
## Номер игрового дня, начиная с 1; увеличивается при завершении ночи.
@export var day_index: int = 1
## Производный счётчик доступных визитов; обновляется контуром обслуживания.
@export var remaining_customer_events: int = 0
@export_group("Shift completion")
## Требует завершения доступных визитов независимо от дополнительных условий смены.
@export var require_finished_customers: bool = true
## Дополнительно требует отсутствия живых клиентов в настроенной зоне.
@export var require_empty_customer_room: bool = false
## Путь от DaySession; пустой путь учитывает всех живых клиентов консервативно.
@export_node_path("Area3D") var customer_room_path: NodePath = NodePath("")
## Минимальная длительность активной дневной смены в секундах; 0 отключает условие.
@export_range(0.0, 86400.0, 1.0, "or_greater") var minimum_shift_seconds: float = 0.0
## Дополнительно требует начала всех незавершённых визитов, назначенных к текущему дню.
@export var require_all_planned_arrivals: bool = false
## Owned clock value; assignment copies exported state so GECS cannot alias prefab clock Resources.
## Only S_GameTime advances the live ticks/remainder; transient step/pause state starts fresh.
@export var clock: GameClock = GameClock.new():
	set(clock_value):
		assert(clock_value != null, "DayCycle requires an owned clock value")
		clock = clock_value.duplicate() as GameClock
## Elapsed timestamp at shift start, or -1 before the first active shift.
@export var shift_start_tick: int = -1
## Captured shift end timestamp, or -1 while the shift is active.
@export var shift_end_tick: int = -1
## Разрешает переход из ночи в утро после успешной подготовки и записи сохранения.
var night_ready: bool = true
## Единственный ожидающий запрос; система извлекает его перед повторной проверкой.
var pending_transition: DayTransitionRequest = null
