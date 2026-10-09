extends Component
## Независимые регистрация, вскрытие и состояние; HP принадлежит C_Health.
class_name C_PackageState

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = [
	"registration",
	"scan",
	"opening",
	"damage",
	"registration_number",
	"registration_day",
	"leaking",
]

enum Registration {
	UNREGISTERED,
	REGISTERED,
	DELIVERED,
	RETURNED,
	BOUGHT_OUT,
}
enum Scan {
	NOT_SCANNED,
	SCANNED,
}
enum Opening {
	CLOSED,
	OPENED,
}
enum Damage {
	UNDAMAGED,
	DAMAGED,
	DESTROYED,
}

## Независимое состояние регистрации и ухода со склада.
@export var registration: Registration = Registration.UNREGISTERED
## Признак состоявшегося сканирования.
@export var scan: Scan = Scan.NOT_SCANNED
## Физическое состояние вскрытия коробки.
@export var opening: Opening = Opening.CLOSED
## Состояние повреждения, производное от Health и событий коробки.
@export var damage: Damage = Damage.UNDAMAGED
## Выделенный номер выдачи; ноль до регистрации.
@export var registration_number: int = 0
## День выделения номера выдачи.
@export var registration_day: int = 0

## Зафиксированная утечка жидкости; подписчики реагируют на типизированное событие Leaking.
@export var leaking: bool = false
