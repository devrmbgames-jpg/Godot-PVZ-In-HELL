extends Component
## Generic semantic goals. Live Entity targets belong to R_NpcMoveTarget/R_NpcLookTarget.
class_name C_NpcIntent

enum LookMode { MOVEMENT, TARGET, HOLD }

@export var movement_active: bool = false
@export var move_position: Vector3 = Vector3.ZERO
@export_range(0.01, 10.0) var arrival_distance: float = 0.25
@export_range(0.0, 1.0) var speed_fraction: float = 1.0
@export var look_mode: LookMode = LookMode.MOVEMENT
@export var look_position: Vector3 = Vector3.ZERO
@export var look_offset: Vector3 = Vector3.ZERO
## May be disabled only for direct authored movement/isolated physics fixtures.
@export var navigation_enabled: bool = true

## Relationship-target mode must not silently fall back to the previous world position.
var move_uses_entity: bool = false
var look_uses_entity: bool = false
var arrived: bool = false
var distance_to_target: float = 0.0
var navigation_pending: bool = false
var navigation_blocked: bool = false
