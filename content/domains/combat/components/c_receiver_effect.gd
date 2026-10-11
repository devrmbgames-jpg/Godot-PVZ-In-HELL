@tool
extends Component
## Authored supernatural area source; S_ReceiverEffect owns its transient cadence.
class_name C_ReceiverEffect

## Immutable alignment, amount and interval tuning; the scene owns Area3D geometry.
@export var definition: DEF_ReceiverEffect = null
## Authored native volume relative to the physical item; no generated gameplay nodes.
@export var area_path: NodePath = ^"EffectArea"
## Unsaved elapsed simulation seconds; reconstruction starts a fresh complete interval.
var tick_elapsed: float = 0.0
