@tool
extends Resource
## Authored local traffic spacing and pair-threat cadence; never owns movement goals.
class_name DEF_NpcTraffic

## Minimum horizontal centre distance from an aggressive neighbour, in metres.
@export_range(0.6, 4.0) var personal_space: float = 1.5
## Anticipation margin for delayed native avoidance/physics samples, in metres.
@export_range(0.05, 0.5) var anticipation_margin: float = 0.2
## Seconds between mutual threats while an aggressive pair blocks passage.
@export_range(0.5, 10.0) var threat_interval: float = 2.0
## Additional subsequent social attack probability per remembered traffic threat.
@export_range(0.0, 0.2) var aggression_step: float = 0.05
## Bounded total contribution from this opponent's traffic threats.
@export_range(0.0, 0.5) var aggression_limit: float = 0.25
