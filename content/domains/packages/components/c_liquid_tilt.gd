extends Component
## Непрерывное опасное наклонение жидкой посылки; S_LiquidTilt исполняет таймер и протечку.
## Таймер/triggered не входят в codec; факт утечки отдельно сохраняется в C_PackageState.
class_name C_LiquidTilt

## Допустимый угол от мирового верха в градусах; безопасная ориентация сбрасывает таймер.
@export_range(0.0, 180.0) var maximum_angle_degrees: float = 60.0
## Непрерывное время опасного наклона до протечки, в gameplay-секундах.
@export_range(0.0, 30.0) var duration_seconds: float = 8.0
## Одноразовый урон типа LIQUID при протечке; 0 оставляет только изменение состояния.
@export_range(0.0, 10000.0) var damage_amount: float = 10.0
## Удержание исправляет крен/наклон через штатный физический solver вращения.
@export var keep_upright_while_held: bool = true
## Предел коррекции вертикальной ориентации при удержании, в радианах/с.
@export_range(0.0, 30.0) var upright_rotation_speed: float = 3.0
## S_LiquidTilt накапливает gameplay-секунды; безопасная ориентация сбрасывает их.
var unsafe_seconds: float = 0.0
## S_LiquidTilt принял command протечки; это ещё не committed C_PackageState.leaking.
var triggered: bool = false
