extends GameDefinition
## Одна авторская атака NPC; C_NpcCombat хранит отдельные наборы ближних и дальних атак.
class_name DEF_NpcAttack

## Базовый урон до голода и сопротивления в единицах здоровья.
@export var damage: float = 12.0
## Минимальная дистанция между позициями тел в метрах.
@export var minimum_range: float = 0.0
## Максимальная дистанция между позициями тел в метрах.
@export var maximum_range: float = 1.8
## Длительность подготовки атаки в секундах.
@export var windup_seconds: float = 0.45
## Длительность активной фазы в секундах.
@export var active_seconds: float = 0.2
## Восстановление после эффекта в секундах.
@export var recovery_seconds: float = 0.4
## Задержка следующей атаки после finish в секундах.
@export var cooldown_seconds: float = 1.2
## Больший приоритет выигрывает; при равенстве сравнивается урон за цикл атаки.
@export_range(-100.0, 100.0, 0.1, "or_less", "or_greater") var selection_priority: float = 0.0
## Доступная анимация использует method-track npc_attack_hit()/npc_attack_finished() вместо таймера.
@export var animation: StringName = &""
## Слои препятствий луча атаки и столкновений снаряда.
@export_flags_3d_physics var collision_mask: int = 31
## Скорость прямого снаряда в м/с для дальнего набора.
@export var projectile_speed: float = 9.0
## Максимальное время жизни снаряда в секундах.
@export var projectile_lifetime: float = 3.0
