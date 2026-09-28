extends Component
## Optional actor-specific providers; empty/absent uses the physical hands provider.
## Providers are stateless adapters, not a second list of owned Entities.
class_name C_ItemAccess

@export var providers: Array[DEF_ItemAccessProvider] = []
