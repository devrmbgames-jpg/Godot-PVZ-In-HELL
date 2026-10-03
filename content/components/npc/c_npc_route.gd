extends Component
## Derived hazard-aware waypoint route; final movement intent retains its original meaning.
class_name C_NpcRoute

## Intermediate navigation waypoints.
var points: PackedVector3Array = PackedVector3Array()
## Next waypoint index.
var point_index: int = 0
## Final goal for which this route was evaluated.
var goal: Vector3 = Vector3.ZERO
## Whether the current intent has an acceptable route.
var reachable: bool = true
## Time since hazard evaluation.
var elapsed: float = 0.0
## Bounded waiting without a traversable safe route.
var blocked_seconds: float = 0.0
