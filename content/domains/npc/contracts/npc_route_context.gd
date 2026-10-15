extends RefCounted
## Detached параметры NpcRouteSolver для одной оценки риска; не кеш и не источник живых целей.
class_name NpcRouteContext


## Горизонтальный опасный объём; конечная half_height дополнительно ограничивает этаж.
class Hazard extends RefCounted:
	## Мировая позиция центра опасности в начале проверки маршрута.
	var center: Vector3 = Vector3.ZERO
	## Радиус в метрах с учётом navigation_agent.radius NPC.
	var radius: float = 0.0
	## Полувысота в метрах; INF отключает вертикальное отсечение горизонтальной оценки.
	var half_height: float = INF
	## Эффективные HP за GamePlay second с учётом сопротивлений NPC и периода hazard tick.
	var damage_rate: float = 0.0


## Опасные объёмы с уже учтёнными сопротивлениями и физическим зазором.
var hazards: Array[Hazard] = []
## Оценка policy speed в м/с из MotionRules, минимум 0.1; не измерение реальной body velocity.
var speed: float = 1.0
