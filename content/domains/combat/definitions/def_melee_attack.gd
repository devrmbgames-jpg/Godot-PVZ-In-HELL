extends GameDefinition
## Авторские время и геометрия удара оружием игрока; атаки NPC используют DEF_NpcAttack.
class_name DEF_MeleeAttack

## Базовый урон удара до голода и сопротивления.
@export var damage: float = 25.0
## Дальность от боевого origin до aim_point в метрах.
@export var reach: float = 2.0
## Половина угла сектора удара в градусах.
@export var half_angle_degrees: float = 60.0
## Длительность замаха в секундах.
@export var windup_seconds: float = 0.25
## Окно попытки попадания в секундах.
@export var active_seconds: float = 0.2
## Длительность восстановления после окна в секундах.
@export var recovery_seconds: float = 0.55
## Слои физических препятствий между оружием участника и целью.
@export_flags_3d_physics var collision_mask: int = 31
