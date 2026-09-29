extends Resource
class_name DEF_CustomerEvent

@export var package_key: StringName = &"books"
## Package-pickup NPCs do not enter the world before the requested shipment is registered.
## Set false only for an event whose NPC has another authored reason to arrive.
@export var requires_registered_package: bool = true
## -1 means this shipment has no scheduled customer.
@export var arrival_delay_days: int = 0
@export var customer: DEF_Customer = null
