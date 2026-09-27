extends GameDefinition
class_name DEF_Customer

@export var display_name: String = "Клиент"
@export var accepts_damaged: bool = true
@export var accepts_opened: bool = true
@export var voluntary_refusal: bool = false
@export var move_speed: float = 1.8
@export var arrival_distance: float = 0.25
@export var approach_timeout: float = 30.0
@export var greeting_seconds: float = 2.0
@export var patience_seconds: float = 180.0
@export var receiving_seconds: float = 1.0
@export var leaving_seconds: float = 4.0
@export var aggressive_seconds: float = 5.0
@export var gravity: float = 20.0
@export var healthy_satisfaction: int = 100
@export var damaged_satisfaction: int = 70
@export var opened_satisfaction: int = 50
@export_range(0.0, 1.0) var complaint_probability: float = 0.85
@export_range(0.0, 1.0) var voluntary_complaint_probability: float = 0.15
@export_range(0.0, 1.0) var false_complaint_probability: float = 0.05
@export_range(0.0, 1.0) var immediate_aggression_probability: float = 0.1
@export_range(1, 30) var complaint_delay_days: int = 1
@export_range(1, 30) var retaliation_days: int = 7
