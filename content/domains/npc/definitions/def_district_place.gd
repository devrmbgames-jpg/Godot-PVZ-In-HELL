extends GameDefinition
## Постоянный адрес, проход, занятие или узел навигации в координатах района.
class_name DEF_DistrictPlace

enum Kind { HOME, PORTAL, ACTIVITY, SHOP, JUNCTION, COVER }
enum Activity { WALK, WATCH_WINDOW, OBSERVE, VISIT_SHOP }

## Свободное занятие после прибытия; не связано с выдачей посылки.
@export var activity: Activity = Activity.WALK
## Смещение посетителя от собственного места торговца.
@export var activity_offset: Vector3 = Vector3.ZERO
## Авторская точка внимания, например окно ПВЗ; не скрытая цель Entity.
@export var focus_path: NodePath = NodePath("")
## Название места для игрока; постоянный ключ служит внутренней связью.
@export var display_name: String = "Место района"

## Категория размещения авторской точки.
@export var kind: Kind = Kind.ACTIVITY
## Позиция относительно корня блокинга района.
@export var position: Vector3 = Vector3.ZERO
## Маркер уровня задаёт X/Z; position.y остаётся авторской высотой земли.
@export var anchor_path: NodePath = NodePath("")
## Связи авторского графа проходов района.
@export var neighbours: PackedStringArray = []
