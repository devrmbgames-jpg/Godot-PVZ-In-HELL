@tool
extends Component
## Авторская добавка к физическому урону при намеренном броске.
## Живую атрибуцию/срок хранит R_ThrownBy; ThrowContext управляет связью, S_ThrowLifetime — часами.
class_name C_ThrowDamage

## Добавка к потенциальному урону после подходящего контакта активного намеренного броска.
@export_range(0.0, 10000.0) var throw_damage: float = 10.0
## Срок атрибуции броска в GamePlay-секундах.
@export_range(0.0, 30.0) var window_seconds: float = 12.0
