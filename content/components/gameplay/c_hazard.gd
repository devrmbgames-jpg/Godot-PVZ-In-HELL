extends Component
## Independent hazard identity, immutable configuration and durable origin attribution.
class_name C_Hazard

## Authored configuration is supplied by the generic factory.
@export var definition: DEF_Hazard = null
## Stable strings survive deletion of the initiating Entity and instigator.
var request_id: String = ""
var origin_id: String = ""
var instigator_id: String = ""
## Optional live attribution, never required for independent effect lifetime.
var instigator: Entity = null

## Optional origin only for excluding its colliders from blast LOS; never a lifetime owner.
var origin: Entity = null
