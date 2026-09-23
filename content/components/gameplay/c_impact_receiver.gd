extends Component
## Opts Health into collision damage with immutable, reusable receiver tuning.
class_name C_ImpactReceiver

## Thresholds and energy conversion; only the profile reference is runtime state.
@export var profile: DEF_ImpactProfile = preload(
	"res://content/definitions/gameplay/impact_default.tres"
)
