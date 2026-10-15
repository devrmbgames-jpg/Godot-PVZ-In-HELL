extends Component
## Сессионные визиты и transient планирование; O_CustomerPlanning владеет календарным планом.
## Customer services фиксируют явные lifecycle/outcome операции; S_CustomerFlow ведёт cooldown.
class_name C_CustomerFlow

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["planned_through_day", "visits"]

## Immutable авторские соответствия коробок правилам визита; runtime их не изменяет.
@export var schedule: DEF_CustomerSchedule = null
## O_CustomerPlanning отмечает последний подготовленный день; повтор не создаёт новый план.
@export var planned_through_day: int = 0
## Постоянные случаи обслуживания; planner создаёт их, lifecycle/outcome операции дополняют историю.
@export var visits: Array[CustomerVisit] = []
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
