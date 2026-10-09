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
## Обычное движение сдвигает свободные лёгкие тела; тяжёлая мебель требует отдельного действия.
@export_range(0.0, 100.0, 0.5, "or_greater") var walk_push_maximum_mass: float = 15.0
## Сила обычного толкания лёгкого свободного тела в ньютонах.
@export_range(0.0, 1000.0, 1.0, "or_greater") var walk_push_force: float = 180.0
## Предел обычного толкания вдоль движения в м/с.
@export_range(0.0, 10.0, 0.1, "or_greater") var walk_push_maximum_speed: float = 3.0

## Плоская скорость внешних игровых импульсов в м/с, отдельно от управляемого движения.
var impulse_velocity: Vector3 = Vector3.ZERO
## Отложенная скорость отскока в м/с; забирается только физическим callback тела.
var pending_rebound_velocity: Vector3 = Vector3.ZERO
## Производный кеш физических контактов для разделений, отдельно от владения и сеанса.
var contact_bodies: Dictionary[int, WeakRef] = {}
