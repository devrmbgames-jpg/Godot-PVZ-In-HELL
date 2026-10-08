extends Component
## Состояние обслуживания сессии дня: политики, постоянные заказы и временная пауза прихода.
class_name C_CustomerFlow

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["planned_through_day", "visits"]

## Авторские соответствия коробок правилам визита.
@export var schedule: DEF_CustomerSchedule = null
## Последний подготовленный день; повтор такта не создаёт новый календарный план.
@export var planned_through_day: int = 0
## Постоянные случаи обслуживания, включая завершённые, погибших и жалобы.
@export var visits: Array[CustomerVisit] = []
## Временная пауза до следующего визита, в секундах; утром сбрасывается, не сохраняется.
var arrival_cooldown_seconds: float = 0.0

## Derived bootstrap/day cache: O_CustomerPlanning writes it; restore invalidates, codecs exclude it.
var planning_day: int = 0
## Last consumed committed phase; -1 requests preparation after materialization/load.
var planning_phase: int = -1

## Производный кеш авторских точек клиентской очереди; живые места резервируют отношения.
var service_routes: NpcServiceRoutes = null
