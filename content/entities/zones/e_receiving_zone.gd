@tool
extends Entity
## Авторская зона приёмки: точки размещения коробок и отображение состояния поставки.
class_name E_ReceivingZone

## Авторский ассортимент, лимиты партии и повторов размещения.
@export var supply: DEF_Delivery = null
## Родитель реально размещённых коробок в дереве сцены.
@export var package_parent: Node3D = null
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _sign_label: Label3D = $Sign


## Возвращает авторский узел SpawnPoints с кандидатами размещения коробок.
func get_spawn_points() -> Node3D:
	return _spawn_points


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var receiving: C_Receiving = get_component(C_Receiving) as C_Receiving
	var cycle: C_DayCycle = DayPhaseService.current()
	if receiving == null or cycle == null or supply == null:
		return

	_sign_label.text = "ПРИЁМКА · цикл %d\nПоставка: %d / %d%s" % [
		cycle.day_index,
		receiving.delivered_counts.get(cycle.day_index, 0),
		mini(supply.maximum_batch_packages, supply.packages.size()),
		"\nОсвободите место для оставшихся коробок" if receiving.blocked else "",
	]
