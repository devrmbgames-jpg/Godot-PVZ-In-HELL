extends GameDefinition
class_name DEF_Economy

@export_range(0, 1000) var buyout_percent: int = 100
@export_range(0, 1000) var lost_percent: int = 120
@export_range(0, 1000) var refusal_percent: int = 150
@export_range(0, 1000) var fraud_percent: int = 200
@export var delivery_payment: int = 100
