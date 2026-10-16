extends Component
## Сессионные визиты и transient планирование; O_CustomerPlanning владеет календарным планом.
## Services commit lifecycle/outcomes/incidents; S_CustomerFlow owns only visit arrival cooldown.
class_name C_CustomerFlow

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"planned_through_day", "visits", "parcel_incident_sequence", "parcel_incidents",
]

## Immutable авторские соответствия коробок правилам визита; runtime их не изменяет.
@export var schedule: DEF_CustomerSchedule = null
## O_CustomerPlanning отмечает последний подготовленный день; повтор не создаёт новый план.
@export var planned_through_day: int = 0
## Постоянные случаи обслуживания; planner создаёт их, lifecycle/outcome операции дополняют историю.
@export var visits: Array[CustomerVisit] = []
## Monotonic wrong-parcel decision sequence; pruning never reuses an RNG decision key.
@export var parcel_incident_sequence: int = 1
## Latest active/held pair incidents; explicit recognition prunes expired completed entries.
@export var parcel_incidents: Array[CustomerParcelIncident] = []
## Transient synchronous operation guard; snapshots and reentrant recognition must wait.
var parcel_reaction_in_progress: bool = false
## Gameplay seconds до визита: lifecycle продлевает, S_CustomerFlow уменьшает.
## Morning/reset обнуляет интервал.
## Transient, не сохраняется; пауза gameplay ticks не расходует этот интервал.
var arrival_cooldown_seconds: float = 0.0

## Derived bootstrap/day cache: O_CustomerPlanning writes it; restore invalidates, codecs exclude
## it.
var planning_day: int = 0
## O_CustomerPlanning's last consumed committed phase; -1 requests preparation after load/reset.
var planning_phase: int = -1

## O_CustomerPlanning increments on context reset so restore rejects previously queued preparation,
## even when day/phase and Component identity are unchanged; never persisted.
var planning_generation: int = 0
## WeakRef to one reconciliation receipt; submit coalesces while the queued handler owns it.
## Reset clears this derived reference; it is not the authority for visit completion/history.
var planning_request: WeakRef = null

## NpcServiceRole лениво читает авторский NpcServiceRoutes; при потере Node разрешает путь заново.
## Derived cache, не сохраняется; живые места резервируют Relationships.
var service_routes: NpcServiceRoutes = null
