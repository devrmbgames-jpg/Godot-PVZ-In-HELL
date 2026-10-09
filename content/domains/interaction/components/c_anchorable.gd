extends Component
## Авторские правила фиксации и временное накопление покоя физической сущности.
class_name C_Anchorable

## Минимальное непрерывное время покоя до разрешения фиксации, в секундах.
@export_range(0.0, 10.0, 0.01, "or_greater") var minimum_rest_seconds: float = 0.5
## Предельная линейная скорость для накопления покоя, в метрах в секунду.
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_linear_speed: float = 0.05
## Предельная угловая скорость покоя, в радианах в секунду.
@export_range(0.0, 10.0, 0.01, "or_greater") var maximum_angular_speed: float = 0.1
## Смещение проверки физической опоры при снятии зависимых креплений, в метрах.
@export_range(0.001, 0.5, 0.001, "or_greater") var support_tolerance: float = 0.05
## Локальное направление поиска опоры предмета; по умолчанию локальный низ.
@export var support_direction_local: Vector3 = Vector3.DOWN

## Накопленное время покоя в секундах: обновляется сервисом через S_AnchorStability и сбрасывается командами.
var stable_seconds: float = 0.0
