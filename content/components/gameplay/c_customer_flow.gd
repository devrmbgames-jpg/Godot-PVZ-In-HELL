extends Component
## Состояние обслуживания сессии дня: политики, постоянные заказы и временная пауза прихода.
class_name C_CustomerFlow

## Авторские соответствия коробок правилам визита.
@export var schedule: DEF_CustomerSchedule = null
## Последний подготовленный день; повтор такта не создаёт новый календарный план.
@export var planned_through_day: int = 0
## Постоянные случаи обслуживания, включая завершённые, погибших и жалобы.
@export var visits: Array[CustomerVisit] = []
## Временная пауза до следующего визита, в секундах; утром сбрасывается, не сохраняется.
var arrival_cooldown_seconds: float = 0.0
