extends Resource
## Постоянная запись поступления; успешная выгрузка автоматически выделяет номер выдачи.
## PackageHistoryService создаёт arrival projection.
## PackageRegistrationService меняет номер/active/departure.
## Примечание и read_event_ids отдельно изменяются history/notice services, не физической коробкой.
class_name PackageRegistrationRecord

## Complete arrival projection; missing fields cannot erase selected contents on restore.
const SAVE_FIELDS: Array[String] = [
	"package_id",
	"history_id",
	"note",
	"read_event_ids",
	"received_day",
	"day_index",
	"number",
	"definition",
	"ordered_item",
	"ordered_quantity",
	"packing_profile",
	"active",
	"departure",
]

## Постоянный ID физической посылки.
@export var package_id: String = ""
## Скрытый стабильный ID истории, скопированный при поступлении коробки.
@export var history_id: String = ""
## Примечание игрока к этой истории; не переносится при переиспользовании номера выдачи.
@export_multiline var note: String = ""
## Прочитанные события этой истории; переиспользование номера выдачи их не переносит.
@export var read_event_ids: PackedStringArray = []
## День фактического поступления, сохраняемый независимо от регистрации и физического тела.
@export var received_day: int = 0
## День выделения номера; 0 у прежнего поступления, ещё не прошедшего регистрацию.
@export var day_index: int = 0
## Номер выдачи; 0 до регистрации, положительный номер резервируется между днями.
@export var number: int = 0
## Авторское определение для просмотра истории после ухода физической коробки.
@export var definition: DEF_Package = null
## Arrival-time immutable order projection for archive display after the physical parcel leaves.
@export var ordered_item: DEF_InventoryItem = null
## Arrival-time unit count; zero only for non-catalog authored contents, never live remaining units.
@export var ordered_quantity: int = 0
## Arrival-time immutable packing reference; retained after opening, rupture or physical departure.
@export var packing_profile: DEF_PackagePacking = null
## Подтверждённого ухода со склада нет; резервируется только положительный номер.
@export var active: bool = true

## Причина ухода со склада, независимая от заявления игрока в журнале.
@export var departure: C_PackageState.Registration = C_PackageState.Registration.DELIVERED
