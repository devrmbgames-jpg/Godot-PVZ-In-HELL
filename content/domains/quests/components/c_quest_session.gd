extends Component
## RefusalQuestService owns records; S_RefusalQuest selects deadlines/outcomes to commit.
class_name C_QuestSession

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["records"]

## Owned records: предложения/выбор/исход/receipt пишет RefusalQuestService, callers читают ссылки.
@export var records: Array[RefusalQuestRecord] = []
