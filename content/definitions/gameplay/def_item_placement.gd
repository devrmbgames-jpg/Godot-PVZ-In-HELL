extends GameDefinition
## Авторские близкие позиции и бюджет безопасного размещения физического предмета.
class_name DEF_ItemPlacement

const MAX_CANDIDATES: int = 16

#region Размещение и бюджет
## Смещения в мировых координатах от точки выпадения; проверяются первые 16.
@export var offsets: PackedVector3Array = PackedVector3Array()
## Слои твёрдых препятствий, включая предметы и персонажей.
@export_flags_3d_physics var obstacle_mask: int = 63
## Слои допустимой опоры; по умолчанию геометрия уровня.
@export_flags_3d_physics var support_mask: int = 1
## Подъём начала луча относительно точки выпадения, в метрах.
@export_range(0.05, 1.0) var probe_rise: float = 0.25
## Максимальная глубина поиска опоры, в метрах.
@export_range(0.5, 20.0) var probe_depth: float = 4.0
## Минимальная вертикальная составляющая нормали допустимой опоры.
@export_range(0.0, 1.0) var support_normal: float = 0.8
## Допустимый перепад пяти точек опоры, в метрах.
@export_range(0.0, 0.5) var support_variation: float = 0.12
## Зазор между нижней границей предмета и опорой, в метрах.
@export_range(0.01, 0.1) var clearance: float = 0.03
## Дополнительный зазор проверки формы и резервов, в метрах.
@export_range(0.0, 0.02) var margin: float = 0.01
## Пауза между повторными попытками очереди, в секундах.
@export_range(0.25, 10.0) var retry_seconds: float = 1.0
## Максимум предметов одной партии, проверяемых сразу при выпадении.
@export_range(1, 16, 1) var initial_budget: int = 8
## Максимум предметов очереди, проверяемых за один повтор.
@export_range(1, 16, 1) var retry_budget: int = 4
#endregion
