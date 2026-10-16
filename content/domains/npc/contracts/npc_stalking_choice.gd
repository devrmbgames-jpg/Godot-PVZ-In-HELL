extends RefCounted
## Once-committed opportunity values; consumers cannot reroll the personal episode.
class_name NpcStalkingChoice

## Personal durable episode sequence assigned by NpcStalkingService.choose.
var sequence: int = 0
## False consumes the opportunity without starting a route.
var selected: bool = false
## Absolute GameClock start after the captured delay.
var ready_tick: int = 0
## Absolute end of the captured approach budget.
var deadline_tick: int = 0
## Extra ticks above the minimum successful cooldown.
var success_extra_ticks: int = 0
## First rear sector used by the bounded native solver.
var candidate_offset: int = 0
