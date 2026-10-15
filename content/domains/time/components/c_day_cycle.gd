extends Component
## Сессионный календарь и авторские условия смены; переходы фиксирует S_DayPhase.
## Clock имеет отдельного writer S_GameTime; restore накладывает сохранённое состояние явно.
class_name C_DayCycle

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"phase",
	"day_index",
	"clock",
	"shift_start_tick",
	"shift_end_tick",
]

enum Phase {
	MORNING,
	DAY,
	EVENING,
	NIGHT,
}

## Фаза, фиксируемая S_DayPhase; NIGHT удерживается до готовности следующего утра.
@export var phase: Phase = Phase.MORNING
## День от 1; S_DayPhase увеличивает его при завершении ночи без добавления elapsed ticks.
@export var day_index: int = 1
## Derived число доступных визитов; S_CustomerArrivals пересчитывает из C_CustomerFlow.
@export var remaining_customer_events: int = 0
@export_group("Shift completion")
## Требует завершения доступных визитов независимо от дополнительных условий смены.
@export var require_finished_customers: bool = true
## Дополнительно требует отсутствия живых клиентов в настроенной зоне.
@export var require_empty_customer_room: bool = false
## Путь от DaySession; пустой путь учитывает всех живых клиентов консервативно.
@export_node_path("Area3D") var customer_room_path: NodePath = NodePath("")
## Минимальная длительность смены в gameplay seconds по clock; 0 отключает условие.
@export_range(0.0, 86400.0, 1.0, "or_greater") var minimum_shift_seconds: float = 0.0
## Дополнительно требует начала всех незавершённых визитов, назначенных к текущему дню.
@export var require_all_planned_arrivals: bool = false
## Owned clock value; assignment copies exported state so GECS cannot alias prefab clock Resources.
## Only S_GameTime advances the live ticks/remainder; transient step/pause state starts fresh.
@export var clock: GameClock = GameClock.new():
	set(clock_value):
		assert(clock_value != null, "DayCycle requires an owned clock value")
		clock = clock_value.duplicate() as GameClock
## S_DayPhase writes the shift-start timestamp in GameTimeRules microsecond ticks; -1 before start.
@export var shift_start_tick: int = -1
## S_DayPhase captures the shift-end microsecond tick; -1 before completion, reset in Morning.
@export var shift_end_tick: int = -1
## S_DayPhase initializes the Night gate; S_NightSave opens it after preparation/write.
## A session without a save slot requires preparation only; this transient flag is not persisted.
var night_ready: bool = true
## DayPhaseService.submit stores one accepted request; S_DayPhase consumes and revalidates it.
## Non-null means pending, not a committed transition; the request has no completion receipt.
var pending_transition: DayTransitionRequest = null
