extends Component
class_name C_PackageState

enum Registration {
	UNREGISTERED,
	REGISTERED,
	DELIVERED,
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

@export var registration: Registration = Registration.UNREGISTERED
@export var scan: Scan = Scan.NOT_SCANNED
@export var opening: Opening = Opening.CLOSED
@export var damage: Damage = Damage.UNDAMAGED
@export var registration_number: int = 0
@export var registration_day: int = 0
