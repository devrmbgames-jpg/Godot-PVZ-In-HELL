extends Component
## Данные прямого полёта, урона и снимка атрибуции снаряда.
class_name C_CombatProjectile

## Постоянная мировая скорость прямого полёта в м/с.
var velocity: Vector3 = Vector3.ZERO
## Остаток времени полёта в секундах.
var remaining_seconds: float = 0.0
## Урон уже с множителем голода стрелка; сопротивление применяется у цели.
var damage: float = 0.0
## Слои луча пройденного отрезка.
var collision_mask: int = 31
## Постоянный снимок контекста запуска без живых ссылок.
var attribution: CombatContext = null
## ID стрелка для атрибуции после исчезновения его Entity.
var instigator_id: String = ""
