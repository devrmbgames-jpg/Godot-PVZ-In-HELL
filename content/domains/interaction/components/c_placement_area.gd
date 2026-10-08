extends Component
## Объём помощи размещению, не контейнер владения; занятость определяется физическими запросами.
class_name C_PlacementArea

## Необязательное требование к размещаемому реальному предмету.
@export var filter: DEF_AccessRequirement = null
## Размер авторского объёма размещения по трём осям, в метрах.
@export var volume_size: Vector3 = Vector3.ONE
## Физические слои препятствий при проверке размещения.
@export_flags_3d_physics var collision_mask: int = 29
## Зазор проверки свободного положения, в метрах.
@export_range(0.0, 0.1, 0.001) var clearance_margin: float = 0.002
