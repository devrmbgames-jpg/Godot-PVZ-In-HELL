extends Resource
## Постоянная запись регистрации; неактивная сохраняет историю, освобождая номер.
class_name PackageRegistrationRecord

## Постоянный ID физической посылки.
@export var package_id: String = ""
## Скрытый стабильный ID истории, скопированный с физической коробки при регистрации.
@export var history_id: String = ""
## Номер дня регистрации.
@export var day_index: int = 0
## Базовый номер выдачи; активная запись сохраняет его между днями.
@export var number: int = 0
## Авторское определение для просмотра истории после ухода физической коробки.
@export var definition: DEF_Package = null
## Только активная складская запись резервирует номер между днями.
@export var active: bool = true

## Причина ухода со склада, независимая от заявления игрока в журнале.
@export var departure: C_PackageState.Registration = C_PackageState.Registration.DELIVERED
