extends DEF_Hazard
## Авторские настройки объёмной опасности; получатели выбираются независимо от типа посылки.
class_name DEF_ToxicArea

## Радиус сферы в метрах; первый периодический урон наступает после полного интервала.
@export_range(0.1, 100.0) var radius: float = 2.0
## Положительный интервал периодического воздействия в секундах.
@export_range(0.05, 60.0) var tick_seconds: float = 4.0
## Урон одного интервала до сопротивления в единицах здоровья.
@export_range(0.0, 10000.0) var damage_per_tick: float = 5.0
## Физические слои кандидатов объёмной опасности.
@export_flags_3d_physics var collision_mask: int = 31
## Ограничивает получателей маркером C_Living.
@export var living_only: bool = true
## Тип воздействия для общего расчёта сопротивлений и оценки риска NPC.
@export var damage_type: DamageRequest.Type = DamageRequest.Type.TOXIC
