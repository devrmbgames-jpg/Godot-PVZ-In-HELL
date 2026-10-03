extends Component
## Запас бега и его состояние; единственный runtime-владелец — S_Sprint.
class_name C_Stamina

@export var base_capacity: float = 70.0
@export var capacity_per_strength: float = 30.0
@export var sprint_speed_multiplier: float = 1.5
## Фиксированный расход: 100 единиц за минуту без груза.
@export var drain_per_second: float = 100.0 / 60.0
@export var recovery_per_second: float = 10.0
@export var recovery_delay_seconds: float = 2.0
@export_range(0.0, 1.0, 0.05) var restart_ratio: float = 0.2
@export var minimum_carry_drain: float = 1.5
@export var maximum_carry_drain: float = 8.0

## В snapshot входят только current/initialized; режим бега никогда не восстанавливается.
var current: float = 100.0
var initialized: bool = false
var maximum: float = 100.0
var recovery_remaining: float = 0.0
var drain_multiplier: float = 1.0
var running: bool = false
var toggled: bool = false
var exhausted: bool = false
var toggle_mode: bool = false
