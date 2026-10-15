extends Component
## Данные прямого полёта, урона и снимка атрибуции снаряда.
class_name C_CombatProjectile

## Постоянная мировая скорость в метрах за GamePlay-секунду; позу меняет S_CombatProjectile.
var velocity: Vector3 = Vector3.ZERO
## Остаток GamePlay-секунд; задаёт ProjectileService, уменьшает S_CombatProjectile.
var remaining_seconds: float = 0.0
## Урон уже с множителем голода стрелка; сопротивление применяется у цели.
var damage: float = 0.0
## Captured ordinary damage bound; flight never reads the launcher's mutable target or trait data.
var minimum_health_fraction: float = 0.0
## Слои луча пройденного отрезка.
var collision_mask: int = 31
## Постоянный снимок контекста запуска без живых ссылок.
var attribution: CombatContext = null
## ID стрелка для атрибуции после исчезновения его Entity.
var instigator_id: String = ""
