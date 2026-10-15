@tool
extends DEF_Hazard
## Авторские настройки объёмной опасности; получатели выбираются независимо от типа посылки.
class_name DEF_ToxicArea

## Радиус объёма в метрах; первый периодический урон наступает после полного интервала.
@export_range(0.1, 100.0) var radius: float = 2.0
## Zero preserves a sphere; positive metres select a thin cylinder centered at the effect origin.
@export_range(0.0, 10.0) var floor_height: float = 0.0
## Положительный интервал в GamePlay-секундах; несколько прошедших тиков объединяются.
@export_range(0.05, 60.0) var tick_seconds: float = 4.0
## Урон одного интервала до сопротивления в единицах здоровья.
@export_range(0.0, 10000.0) var damage_per_tick: float = 5.0
## Физические слои кандидатов объёмной опасности.
@export_flags_3d_physics var collision_mask: int = 31
## Ограничивает получателей маркером C_Living.
@export var living_only: bool = true
## Тип воздействия для общего расчёта сопротивлений и оценки риска NPC.
@export var damage_type: DamageRequest.Type = DamageRequest.Type.TOXIC
