extends Component
## Временное состояние владельца намерения; не хранит физические transform и ссылки на цели.
class_name C_NpcDecision

enum Owner { EMERGENCY, COMBAT, SERVICE, SCHEDULE, IDLE, NONE }

## Ветка решения, имеющая право задавать движение и действия.
var intent_owner: Owner = Owner.NONE
## Название текущего поведения для отладки.
var active_behavior: String = ""
## Накопленное время до следующего обновления AI.
var update_elapsed: float = 0.0
## Время ожидания недостижимой цели.
var blocked_elapsed: float = 0.0
