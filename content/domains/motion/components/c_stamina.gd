extends Component
## Запас бега; scheduled writer — S_Sprint, current/initialized также восстанавливает codec.
class_name C_Stamina

## Domain-owned durable field contract consumed by the closed persistence codec.
const SAVE_FIELDS: Array[String] = ["current", "initialized"]

## Базовый запас выносливости без вклада силы.
@export var base_capacity: float = 70.0
## Добавка запаса на единицу вычисленной силы.
@export var capacity_per_strength: float = 30.0
## Множитель скорости разрешённого бега.
@export var sprint_speed_multiplier: float = 1.5
## Базовый расход единиц за gameplay-секунду без груза; по умолчанию 100 за минуту.
@export var drain_per_second: float = 100.0 / 60.0
## Восстановление единиц за gameplay-секунду после задержки.
@export var recovery_per_second: float = 10.0
## Пауза восстановления после фактического бега в gameplay-секундах.
@export var recovery_delay_seconds: float = 2.0
## Доля максимума 0–1 для выхода из истощения.
@export_range(0.0, 1.0, 0.05) var restart_ratio: float = 0.2
## Множитель расхода при минимальной доле допустимого груза.
@export var minimum_carry_drain: float = 1.5
## Множитель расхода при максимальной допустимой массе Carry.
@export var maximum_carry_drain: float = 8.0

## В snapshot входят только current/initialized; режим бега никогда не восстанавливается.
var current: float = 100.0
## S_Sprint заполняет запас лишь при false; восстановленное true запрещает повторное заполнение.
var initialized: bool = false
## S_Sprint пересчитывает максимум из base_capacity и силы, затем ограничивает current.
var maximum: float = 100.0
## Остаток задержки восстановления в gameplay-секундах; transient, в SAVE_FIELDS не входит.
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
