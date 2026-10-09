extends Component
## Временное состояние владельца намерения; не хранит физические transform и ссылки на цели.
class_name C_NpcDecision

enum Owner { EMERGENCY, COMBAT, SERVICE, SCHEDULE, IDLE, NONE }

## Ветка решения, имеющая право задавать движение и действия.
var intent_owner: Owner = Owner.NONE
## Токен листа, задавшего движение; прерывание старого действия не отменяет движение его замены.
var active_task_id: int = 0
## Защищает остановку участия от вложенного abort во время исполнения текущего такта BT.
var tree_updating: bool = false
## Название текущего поведения для отладки.
var active_behavior: String = ""
## Время ожидания недостижимой цели.
var blocked_elapsed: float = 0.0

## Transient interval captured by cadence, shared through sensing/traits/BT and cleared by route progression.
var scheduled_delta: float = 0.0
## Calendar day captured by the cadence owner; queued stages reject superseded steps.
var scheduled_day: int = 0
## Calendar phase captured by the cadence owner; not persistent NPC history.
var scheduled_phase: int = -1
