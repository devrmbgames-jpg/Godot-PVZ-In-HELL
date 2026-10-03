extends Component
## Runtime body-owned contact snapshot inbox; capture writes and scheduled impact drains it.
class_name C_ImpactInbox

## Latest physics callback's manifolds, bounded by the body's contact reporting limit.
var contacts: Array[PhysicsContact] = []
## Native kinematic bodies have no body_exited signal; their contact bridge reports separations.
var separations: Array[PhysicsContact] = []
