extends Component
## DaySession owns the persistent schedule and visit/dispute records.
class_name C_CustomerFlow

@export var schedule: DEF_CustomerSchedule = null
@export var planned_through_day: int = 0
@export var visits: Array[CustomerVisit] = []
