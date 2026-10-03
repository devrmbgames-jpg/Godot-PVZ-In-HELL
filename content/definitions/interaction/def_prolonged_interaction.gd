extends GameDefinition
## Optional timing policy for a contextual action; never mutable runtime progress.
class_name DEF_ProlongedInteraction

enum ResetPolicy { DECAY, INSTANT, ON_COMPLETE, NEVER }

@export_range(0.01, 60.0, 0.01, "or_greater") var duration_seconds: float = 6.0
@export var reset_policy: ResetPolicy = ResetPolicy.INSTANT
## Normalized progress lost per idle second, independently of duration.
@export_range(0.0, 10.0, 0.01, "or_greater") var decay_per_second: float = 0.125
