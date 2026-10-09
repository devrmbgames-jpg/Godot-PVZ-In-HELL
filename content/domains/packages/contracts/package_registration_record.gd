extends Resource
## Постоянная запись поступления; номер выдачи появляется только после сканирования.
class_name PackageRegistrationRecord

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
## Номер дня регистрации; 0 означает, что коробку ещё не сканировали.
@export var day_index: int = 0
## Номер выдачи; 0 до сканирования, положительный номер резервируется между днями.
@export var number: int = 0
## Авторское определение для просмотра истории после ухода физической коробки.
@export var definition: DEF_Package = null
## Подтверждённого ухода со склада нет; резервируется только положительный номер.
@export var active: bool = true

## Причина ухода со склада, независимая от заявления игрока в журнале.
@export var departure: C_PackageState.Registration = C_PackageState.Registration.DELIVERED
