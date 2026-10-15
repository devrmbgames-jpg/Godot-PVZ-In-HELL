extends Component
## ID поиска постоянной записи задания; исход принадлежит RefusalQuestRecord.
## RefusalQuestService создаёт transient binding Entity и удаляет при resolve; restore пересобирает.
class_name C_QuestBinding

## Устойчивый ID соответствующей записи сессионного журнала.
@export var quest_id: StringName = &""
