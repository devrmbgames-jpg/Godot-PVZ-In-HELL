extends Component
## Сессионный журнал заданий с устойчивыми ID и сохранёнными исходами.
class_name C_QuestSession

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["records"]

## Постоянные предложения, принятые задания и разрешённые исходы.
@export var records: Array[RefusalQuestRecord] = []
