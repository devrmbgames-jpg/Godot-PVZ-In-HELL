extends Component
## Materialized immutable definition and transient acquisition generation for this incarnation.
class_name C_SmartObject

## Authored schema copied by the common compiler; never a mutable reservation registry.
@export var definition: DEF_SmartObject = null
## Owning SmartObjectService advances this per-incarnation counter; it is not saved.
var acquisition_sequence: int = 0
