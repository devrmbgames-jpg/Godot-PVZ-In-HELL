extends Component
## Payload of effect -> owner Relationship for a non-rigid hazard Entity.
class_name R_HazardFollow

## Owner is Relationship.target, never a duplicated payload reference or scene parent.
var local_offset: Transform3D = Transform3D.IDENTITY
var on_loss: DEF_Hazard.OwnerLoss = DEF_Hazard.OwnerLoss.Detach
