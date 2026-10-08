extends Component
## Непрерывное опасное наклонение жидкой посылки; S_LiquidTilt исполняет таймер и протечку.
class_name C_LiquidTilt

## Допустимый угол от мирового верха в градусах; безопасная ориентация сбрасывает таймер.
@export_range(0.0, 180.0) var maximum_angle_degrees: float = 60.0
## Непрерывное время опасного наклона до протечки, в секундах.
@export_range(0.0, 30.0) var duration_seconds: float = 8.0
## Одноразовый урон типа LIQUID при протечке; 0 оставляет только изменение состояния.
@export_range(0.0, 10000.0) var damage_amount: float = 10.0
## Удержание исправляет крен/наклон через штатный физический solver вращения.
@export var keep_upright_while_held: bool = true
## Предел коррекции вертикальной ориентации при удержании, в радианах/с.
@export_range(0.0, 30.0) var upright_rotation_speed: float = 3.0
## Накопленные секунды непрерывного опасного наклона.
var unsafe_seconds: float = 0.0
## Одноразовый запрет повторного запуска протечки после достижения порога.
var triggered: bool = false
