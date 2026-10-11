@tool
extends Component
## Persistent player alignment; KarmaService owns runtime mutation, persistence restores snapshots.
class_name C_Karma

## Closed durable contract; the immutable policy is encoded by its authored resource path.
const SAVE_FIELDS: Array[String] = ["value", "policy"]

## Current alignment within the authored policy bounds; neutral starts at zero.
@export var value: float = 0.0
## Bounds and strict supernatural thresholds shared with receiver eligibility.
@export var policy: DEF_KarmaPolicy = preload(
	"res://content/domains/combat/definitions/def_karma_default.tres"
)
