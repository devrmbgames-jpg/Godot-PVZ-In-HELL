extends Component
## DaySession owns the persistent schedule and visit/dispute records.
class_name C_CustomerFlow

@export var schedule: DEF_CustomerSchedule = null
@export var planned_through_day: int = 0
@export var visits: Array[CustomerVisit] = []
## Transient inter-visit clock, reset at Morning; visits remain the persistent authority.
var arrival_cooldown_seconds: float = 0.0
