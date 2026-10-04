extends DEF_ChallengeCondition
## Авторское правило взгляда, препятствий и предупреждения о нарушении.
class_name DEF_GazeChallengeCondition

## Требует смотреть на носителя либо отводить взгляд.
@export var required_attention: bool = false
## Половина сектора направленного взгляда в градусах.
@export_range(1.0, 89.0) var half_angle_degrees: float = 20.0
## Максимальная дальность условия в метрах.
@export_range(0.1, 100.0) var maximum_distance: float = 12.0
## Слои препятствий взгляда; тело самого игрока исключается отдельно.
@export_flags_3d_physics var collision_mask: int = 27
## Доля допуска нарушения 0–0.99, после которой появляется предупреждение.
@export_range(0.0, 0.99) var warning_fraction: float = 0.5
## Текст предупреждения перед учётом нарушения.
@export_multiline var warning_text: String = "Не смотрите на меня!"
