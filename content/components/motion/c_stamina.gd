extends Component
## Запас бега и его состояние; единственный runtime-владелец — S_Sprint.
class_name C_Stamina

## Базовый запас выносливости без вклада силы.
@export var base_capacity: float = 70.0
## Добавка запаса на единицу вычисленной силы.
@export var capacity_per_strength: float = 30.0
## Множитель скорости разрешённого бега.
@export var sprint_speed_multiplier: float = 1.5
## Фиксированный расход: 100 единиц за минуту без груза.
@export var drain_per_second: float = 100.0 / 60.0
## Восстановление единиц запаса за секунду после задержки.
@export var recovery_per_second: float = 10.0
## Пауза восстановления после фактического бега в секундах.
@export var recovery_delay_seconds: float = 2.0
## Доля максимума 0–1 для выхода из истощения.
@export_range(0.0, 1.0, 0.05) var restart_ratio: float = 0.2
## Множитель расхода при минимальной доле допустимого груза.
@export var minimum_carry_drain: float = 1.5
## Множитель расхода при максимальной допустимой массе Carry.
@export var maximum_carry_drain: float = 8.0

## В snapshot входят только current/initialized; режим бега никогда не восстанавливается.
var current: float = 100.0
## Запас уже инициализирован; сохранение не пополняет его снова.
var initialized: bool = false
## Производный максимум из base_capacity и силы.
var maximum: float = 100.0
## Остаток задержки восстановления в секундах.
var recovery_remaining: float = 0.0
## Производный множитель расхода из фактической массы Carry.
var drain_multiplier: float = 1.0
## Разрешённый бег сопровождается фактическим движением и расходом.
var running: bool = false
## Запрос бега закреплён нажатием в режиме переключателя.
var toggled: bool = false
## После исчерпания требуется достигнуть restart_ratio.
var exhausted: bool = false
## Последний режим настройки бега для сброса запроса при смене режима.
var toggle_mode: bool = false
