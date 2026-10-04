extends RefCounted
## One planning transaction: derived geometry, risk inputs and reusable segment evaluations.
class_name NpcRouteContext

## Effective damaging sphere captured from a live hazard.
class Hazard extends RefCounted:
	## World center at the start of this plan.
	var center: Vector3 = Vector3.ZERO
	## Clearance including the traveler's physical radius.
	var radius: float = 0.0
	## Effective damage per second after the traveler's resistance.
	var damage_rate: float = 0.0

## Additive result reused when a graph edge is visited from another entrance.
class Evaluation extends RefCounted:
	## Combined length, damage and light cost.
	var cost: float = INF
	## Expected effective health loss along this segment.
	var damage: float = INF

## Scene-local tuning used throughout this transaction.
var district: C_District = null
## Shared light inputs, with point samples scoped to this transaction below.
var lighting: NpcLightingContext = null
## Optional permanent light aversion rule.
var light_rule: DEF_NpcTrait = null
## Bodies excluded by this traveler's illumination samples.
var ignored_bodies: Array[RID] = []
## Harmful volumes with resistance and clearance already applied.
var hazards: Array[Hazard] = []
## Actual movement speed used for exposure duration.
var speed: float = 1.0
## Maximum permissible damage for this decision.
var risk_budget: float = 0.0
## Emergency escape must leave positive health, including at the exact budget boundary.
var requires_health_after_escape: bool = false
## Stable world positions resolved once for graph lookup and sorting.
var positions: Dictionary[StringName, Vector3] = {}
## Authored graph junctions.
var junctions: Array[DEF_DistrictPlace] = []
## Exact point samples reused only within the same synchronous plan.
var light_samples: Dictionary[Vector3, float] = {}
## Evaluations reused across graph searches within this synchronous plan.
var edge_evaluations: Dictionary[String, Evaluation] = {}
