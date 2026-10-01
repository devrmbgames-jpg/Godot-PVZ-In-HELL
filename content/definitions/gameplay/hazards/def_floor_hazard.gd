extends DEF_Hazard
class_name DEF_FloorHazard

@export var size: Vector2 = Vector2(4.0, 4.0)
@export_range(0.001, 0.2) var contact_tolerance: float = 0.06
@export_range(0.05, 10.0) var tick_seconds: float = 0.5
@export_range(0.0, 1000.0) var damage_per_tick: float = 6.0
@export var preparation_color: Color = Color(1.0, 0.65, 0.05, 0.45)
@export var active_color: Color = Color(1.0, 0.1, 0.02, 0.65)
