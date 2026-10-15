extends Component
## Derived route: S_NpcRoute owns clocks, S_NpcRoutePlanning builds paths, S_NpcIntent consumes
## waypoints.
class_name C_NpcRoute

## Мировые точки пути, в метрах; S_NpcRoutePlanning строит, lifecycle/риск инвалидирует.
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
## GamePlay seconds до проверки риска/карты; S_NpcRoute накапливает, planning также сбрасывает.
var elapsed: float = 0.0
## Текущая цель ожидает своей очереди планирования.
var pending: bool = false
## Bounded failed refuge projections; planning publishes them, route lifecycle clears invalidation.
## Derived navigation feedback only; never serialized or used as a second movement goal owner.
var rejected_refuge_points: PackedVector3Array = PackedVector3Array()
## Bounded direction cursor after actual failed escape planning; never serialized.
## Planning advances it; danger exit, map invalidation and reconstruction reset it.
var refuge_direction_offset: int = 0
## GamePlay seconds без доступного безопасного маршрута; S_NpcRoute владеет watchdog.
var blocked_seconds: float = 0.0
## Признак начального измерения физического продвижения по текущей цели.
var progress_initialized: bool = false
## Последняя мировая позиция достаточного продвижения в метрах, с y=0 для проверки по земле.
var progress_position: Vector3 = Vector3.ZERO
## GamePlay seconds без достаточного физического продвижения; S_NpcRoute накапливает/сбрасывает.
var stalled_seconds: float = 0.0


#region Transient route lifecycle
## Clears derived navigation state while retaining the actor's compiled route capability.
func reset_transient_state() -> void:
	points.clear()
	point_index = 0
	goal = Vector3.ZERO
	navigation_map = RID()
	map_iteration = -1
	reachable = true
	elapsed = 0.0
	pending = false
	rejected_refuge_points.clear()
	refuge_direction_offset = 0
	blocked_seconds = 0.0
	progress_initialized = false
	progress_position = Vector3.ZERO
	stalled_seconds = 0.0
#endregion
