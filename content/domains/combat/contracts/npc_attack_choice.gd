extends RefCounted
## Результат выбора без живой цели; противник принадлежит R_CombatTarget участника.
class_name NpcAttackChoice

## Выбранный ближний или дальний набор атак.
var kind: C_NpcCombat.Kind = C_NpcCombat.Kind.MELEE
## Индекс внутри выбранного набора; -1 означает отсутствие выбора.
var variant: int = -1
## Авторский приоритет среди доступных атак.
var priority: float = 0.0
## Потенциальный урон за секунду полного цикла для разрешения равного приоритета.
var damage_rate: float = 0.0
