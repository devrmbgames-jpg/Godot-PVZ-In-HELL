extends Component
## Attach to any Entity to emit a reusable hazard manually or through lifecycle events.
class_name C_HazardEmitter

enum Trigger {
	HealthDepleted = 1,
	PackageDestroyed = 2,
	PackageLeaking = 4,
	PackageOpened = 8,
}

## Effect and automatic triggers; a generic explicit activation can ignore the trigger mask.
@export var definition: DEF_Hazard = null
@export_flags(
	"Health depleted:1",
	"Package destroyed:2",
	"Package leaking:4",
	"Package opened:8",
) var triggers: int = Trigger.HealthDepleted
@export var one_shot: bool = true
## Runtime producer guard/counter; persist these alongside origin identity when saving.
var fired: bool = false
var sequence: int = 0
