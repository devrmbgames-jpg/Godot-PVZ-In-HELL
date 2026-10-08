extends Component
## Авторские параметры маркера и временное состояние сеанса рисования.
class_name C_Marker

## Максимальная дистанция рисования по поверхности, в метрах.
@export var drawing_range: float = 3.0
## Толщина чернильного штриха, в метрах.
@export var ink_width: float = 0.012
## Цвет чернил, копируемый при начале каждого штриха.
@export var ink_color: Color = Color(0.025, 0.035, 0.09)
## Минимальный промежуток между точками штриха, в метрах.
@export var sample_spacing: float = 0.004
## Предельное число точек чернил на одной коробке.
@export var max_package_points: int = 4096
## Токен захвата ввода для рисования; держатель предмета определяется через R_HeldBy.
var capture_token: int = 0
## Текущая позиция указателя рисования в координатах экрана.
var pointer: Vector2 = Vector2.ZERO
## Текущая коробка для непрерывного штриха; временная ссылка, не владение предметом.
var parcel: Entity = null
## Продолжаемый штрих коробки; ссылка сбрасывается при разрыве рисования.
var stroke: PackageMarkStroke = null

## Transient input receipt written only by S_Marker; never persisted with package ink.
var last_input_tick: int = -1
## Capture identity paired with the receipt; a new session is a distinct operation.
var last_processed_capture: int = 0
