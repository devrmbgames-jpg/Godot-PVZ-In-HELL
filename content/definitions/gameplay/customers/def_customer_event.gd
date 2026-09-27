extends Resource
class_name DEF_CustomerEvent

@export var package_key: StringName = &"books"
## -1 means this shipment has no scheduled customer.
@export var arrival_delay_days: int = 0
@export var customer: DEF_Customer = null
