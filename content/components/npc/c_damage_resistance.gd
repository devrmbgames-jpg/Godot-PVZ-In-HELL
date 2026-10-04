extends Component
## Множители типов урона; ноль даёт одинаковый иммунитет в уроне и оценке пути.
class_name C_DamageResistance

## Неуказанные типы имеют множитель 1; авторские значения конечны и неотрицательны.
@export var multipliers: Dictionary[int, float] = {}
