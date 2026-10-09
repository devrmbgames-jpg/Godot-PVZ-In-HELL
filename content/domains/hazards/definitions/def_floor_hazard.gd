extends DEF_Hazard
## Авторские параметры плоской опасности сценарного испытания.
class_name DEF_FloorHazard

## Размер плоскости по локальным X/Z в метрах.
@export var size: Vector2 = Vector2(4.0, 4.0)
## Допуск контакта с плоскостью в метрах.
@export_range(0.001, 0.2) var contact_tolerance: float = 0.06
## Интервал урона активного испытания в секундах.
@export_range(0.05, 10.0) var tick_seconds: float = 2.0
## Урон активного интервала до сопротивления.
@export_range(0.0, 1000.0) var damage_per_tick: float = 6.0
## Цвет предупреждения до активной опасности.
@export var preparation_color: Color = Color(1.0, 0.65, 0.05, 0.45)
## Цвет активной опасности.
@export var active_color: Color = Color(1.0, 0.1, 0.02, 0.65)
