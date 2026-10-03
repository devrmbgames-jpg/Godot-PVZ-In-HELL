extends GameDefinition
## Immutable authored shop stock, opening schedule and courier offer.
class_name DEF_TraderProfile

@export var display_name: String = "Торговец"
@export var catalog: Array[DEF_InventoryItem] = []
@export_range(1, 365) var first_day: int = 1
@export_range(1, 365) var repeat_days: int = 1
@export_flags("Morning:1", "Day:2", "Evening:4", "Night:8") var open_phases: int = 4
@export var home_delivery_enabled: bool = true
@export_range(0, 1000000000) var delivery_fee: int = 30
@export_range(1, 30) var delivery_delay_days: int = 1

