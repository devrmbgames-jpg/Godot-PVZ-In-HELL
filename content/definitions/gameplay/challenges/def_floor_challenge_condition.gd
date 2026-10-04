extends DEF_ChallengeCondition
## Авторская сцена и мировое положение плоской опасности испытания.
class_name DEF_FloorChallengeCondition

## Автономная сцена E_FloorHazard.
@export var hazard_scene: PackedScene = null
## Мировое положение плоскости в метрах.
@export var world_position: Vector3 = Vector3(4.0, 0.0, -2.0)
