@tool
extends Entity
class_name E_ReceivingZone

@export var supply: DEF_Delivery = null
@export var package_parent: Node3D = null
@onready var spawn_points: Node3D = $SpawnPoints
@onready var sign_label: Label3D = $Sign


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var receiving: C_Receiving = get_component(C_Receiving) as C_Receiving
	var cycle: C_DayCycle = S_DayPhase.current()
	if receiving == null or cycle == null or supply == null:
		return
	sign_label.text = "ПРИЁМКА · цикл %d\nПоставка: %d / %d%s" % [
		cycle.day_index,
		receiving.delivered_counts.get(cycle.day_index, 0),
		supply.packages.size(),
		"\nОсвободите место для оставшихся коробок" if receiving.blocked else "",
	]
