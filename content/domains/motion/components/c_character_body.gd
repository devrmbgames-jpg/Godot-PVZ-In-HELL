extends Component
## Авторская кинематическая реакция и производные контакты; общей скоростью владеет native body.
class_name C_CharacterBody

## Множитель native-гравитации при кинематическом движении.
@export var gravity_scale: float = 1.0
## Эффективная масса персонажа в кг для контактов и преобразования импульса.
@export var mass_kg: float = 60.0
## Скорость затухания плоской импульсной скорости в м/с².
@export var impulse_decay_per_second: float = 8.0
## Доля нормальной скорости контакта, возвращаемая как отскок.
@export var impact_rebound_fraction: float = 0.35
## Максимальная скорость отскока в м/с.
@export var maximum_rebound_speed: float = 8.0
## Импульс в секунду на подвижную опору в Н·с/с.
@export var ground_impulse_per_second: float = 6.0
## Предел изменения скорости опоры за такт в м/с.
@export var ground_maximum_velocity_change: float = 0.8
## Угол взгляда вниз в градусах, после которого корпус сохраняет ориентацию для поясных слотов.
@export var slot_look_down_degrees: float = 55.0
## Максимальная высота проверяемого шага в метрах.
@export var step_height: float = 0.2
## Базовый предел массы в кг; KinematicPushSolver умножает его на текущую Strength.
@export_range(0.0, 100.0, 0.5, "or_greater") var walk_push_maximum_mass: float = 15.0
## Базовая сила толкания в Н; KinematicPushSolver умножает её на текущую Strength.
@export_range(0.0, 1000.0, 1.0, "or_greater") var walk_push_force: float = 180.0
## Предел обычного толкания вдоль движения в м/с.
@export_range(0.0, 10.0, 0.1, "or_greater") var walk_push_maximum_speed: float = 3.0

## Ограничивает суммарное внешнее движение; отключено у существующего игрока.
@export var bounded_external_motion: bool = false
## Предел горизонтальной внешней скорости в м/с, отдельно от собственного управления.
@export_range(0.0, 20.0, 0.1, "or_greater") var maximum_external_planar_speed: float = 3.0
## Предел дополнительной скорости вверх в м/с, отдельно от гравитации.
@export_range(0.0, 5.0, 0.1, "or_greater") var maximum_external_upward_speed: float = 1.0

## Мировая скорость внешних импульсов в м/с, не полная скорость body.
## KinematicCharacterSolver затухает её и согласует с native slide; capture только пишет контакты.
var impulse_velocity: Vector3 = Vector3.ZERO
## Мировая скорость отскока в м/с: KinematicImpactCapture накапливает,
## KinematicCharacterSolver забирает и обнуляет при следующем шаге тела.
var pending_rebound_velocity: Vector3 = Vector3.ZERO
## KinematicImpactCapture заменяет кеш после slide при наличии C_ImpactInbox.
## Ключ — instance ID, WeakRef не удерживает body; прошлый кеш нужен для separations.
var contact_bodies: Dictionary[int, WeakRef] = { }

## Previous physical-step samples near the authored impact probe; never contact/damage authority.
## The native contact must still confirm the pair before its incoming point velocity is used.
var incoming_bodies: Dictionary[int, BodyMotion] = { }


## Weak native-body sample, bounded by the probe's result count and replaced every physics step.
class BodyMotion:
	extends RefCounted
	## Collider lifetime is checked before using the sample at a subsequent contact.
	var body: WeakRef
	## World centre velocity in m/s before contact response.
	var linear_velocity: Vector3
	## World angular velocity in rad/s before contact response.
	var angular_velocity: Vector3
	## Physics frame at capture; stale approach samples never arm a later contact.
	var tick: int
