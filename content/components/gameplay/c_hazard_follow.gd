extends Component
## Optional generic owner-follow relationship data for a non-rigid hazard Entity.
class_name C_HazardFollow

## Owner is not retained by scene parenting; loss follows the explicit policy.
var origin: Entity = null
var local_offset: Transform3D = Transform3D.IDENTITY
var on_loss: DEF_Hazard.OwnerLoss = DEF_Hazard.OwnerLoss.Detach
