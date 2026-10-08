extends Component
## Множители типов урона; ноль даёт одинаковый иммунитет в уроне и оценке пути.
class_name C_DamageResistance

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["multipliers"]

## Неуказанные типы имеют множитель 1; авторские значения конечны и неотрицательны.
@export var multipliers: Dictionary[int, float] = {}
