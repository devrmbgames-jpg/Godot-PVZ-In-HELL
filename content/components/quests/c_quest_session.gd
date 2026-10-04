extends Component
## Сессионный журнал заданий с устойчивыми ID и сохранёнными исходами.
class_name C_QuestSession

## Постоянные предложения, принятые задания и разрешённые исходы.
@export var records: Array[RefusalQuestRecord] = []
