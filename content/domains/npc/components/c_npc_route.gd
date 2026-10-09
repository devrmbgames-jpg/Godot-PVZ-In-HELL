extends Component
## Derived route: S_NpcRoute owns clocks, S_NpcRoutePlanning builds paths, S_NpcIntent consumes waypoints.
class_name C_NpcRoute

## Промежуточные точки движения по маршруту.
var points: PackedVector3Array = PackedVector3Array()
## Индекс следующей точки маршрута.
var point_index: int = 0
## Конечная цель, для которой был построен маршрут.
var goal: Vector3 = Vector3.ZERO
## Нативная карта навигации построенного пути; не сохраняется.
var navigation_map: RID = RID()
## Ревизия navmesh при построении пути; -1 требует начального планирования.
var map_iteration: int = -1
## У текущего намерения есть допустимый маршрут.
var reachable: bool = true
## Время с последней оценки опасности.
var elapsed: float = 0.0
## Текущая цель ожидает своей очереди планирования.
var pending: bool = false
## Время ожидания без доступного безопасного маршрута.
var blocked_seconds: float = 0.0
## Признак начального измерения физического продвижения по текущей цели.
var progress_initialized: bool = false
## Последняя физическая позиция, в которой замечено достаточное продвижение.
var progress_position: Vector3 = Vector3.ZERO
## Время без физического продвижения по формально доступному пути.
var stalled_seconds: float = 0.0
