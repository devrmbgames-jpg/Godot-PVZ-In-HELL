extends Component
## Складской журнал; выделение номеров и переходы записей принадлежат сервису регистрации.
class_name C_PackageLedger

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"records",
	"history_sequence_day",
	"next_history_number",
	"last_departed_package_id",
]

## Все поступления и регистрации, включая неактивные для сохранения истории.
@export var records: Array[PackageRegistrationRecord] = []
## День счётчика скрытых ID истории; сохраняется вместе с журналом.
@export var history_sequence_day: int = 0
## Следующий свободный порядковый номер скрытой истории в данном дне.
@export var next_history_number: int = 1
## ID последней покинувшей склад коробки для отображения после освобождения её номера.
@export var last_departed_package_id: String = ""
