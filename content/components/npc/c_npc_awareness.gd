extends Component
## Derived perception and search progress; live opponent identity belongs to Relationships.
class_name C_NpcAwareness

## Whether the bound opponent is currently confirmed by sight.
var target_visible: bool = false
## Whether the player is currently confirmed by sight.
var player_visible: bool = false
## Last confirmed opponent position; never updated through a hidden live target.
var last_seen_position: Vector3 = Vector3.ZERO
## Whether any valid opponent position has been confirmed.
var has_last_seen: bool = false
## Time since the opponent was last confirmed.
var search_elapsed: float = 0.0
## Last audible stimulus position, without assumed source identity.
var heard_position: Vector3 = Vector3.ZERO
## Remaining investigation time for an unrecognized noise.
var heard_remaining: float = 0.0
## Whether an immediate reaction requests fleeing.
var fleeing: bool = false
## Sustained visible player retreat in an active confrontation.
var retreat_elapsed: float = 0.0
## Elapsed idle time before another activity.
var idle_elapsed: float = 0.0
## Last consumed stimulus sequence; one noise cannot continually renew search.
var last_noise_sequence: int = 0
## Footstep emission accumulator.
var footstep_elapsed: float = 0.0
## Sustained exposure per supernatural rule.
var rule_exposure: Dictionary[int, float] = {}
## Warning guards scoped to the current encounter.
var warned_rules: Array[int] = []
## Consequences already committed in the current encounter.
var reacted_rules: Array[int] = []
## Search point currently being checked.
var search_index: int = 0
## Lighting distress requests a dark refuge through the emergency branch.
var light_distress: bool = false

## Immediate effective hazard exposure requires escaping the current volume.
var hazard_distress: bool = false

## Once per phase the person may call out; opening the modal always requires interaction.
var called_out: bool = false
