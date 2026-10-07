@tool
extends Entity
## Авторская зона приёмки: точки размещения коробок и отображение состояния поставки.
class_name E_ReceivingZone

## Запрашивает обработку живого обратного груза до окончания утра; последующий этап подключает учёт.
signal cargo_commit_requested(truck: E_MorningTruck, batch_id: String)

## Авторский ассортимент, лимиты партии и повторов размещения.
@export var supply: DEF_Delivery = null
## Родитель реально размещённых коробок в дереве сцены.
@export var package_parent: Node3D = null
## Авторская стоянка; пустая ссылка сохраняет прежнюю приёмку для изолированных сцен.
@export var truck_parking: Marker3D = null
## Сцена статичной машины с дверью и экспортируемыми грузовыми местами.
@export var truck_scene: PackedScene = preload("res://content/entities/car/car.tscn")

const STATUS_REFRESH_SECONDS: float = 0.25
var _status_remaining: float = 0.0
var _truck: E_MorningTruck = null

@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _sign_label: Label3D = $Sign


#region Машина и авторские места
## Возвращает авторский узел SpawnPoints с кандидатами размещения коробок.
func get_spawn_points() -> Node3D:
	return _spawn_points

## Возвращает живой экземпляр машины без создания и изменения состояния.
func get_truck() -> E_MorningTruck:
	return _truck if is_instance_valid(_truck) and not _truck.is_queued_for_deletion() else null


## Создаёт одну машину на стоянке; поза задаётся до входа тела в SceneTree.
func ensure_truck() -> E_MorningTruck:
	if get_truck() != null:
		return _truck
	if not is_instance_valid(truck_parking) or truck_scene == null:
		return null

	var instance: Node = truck_scene.instantiate()
	var truck: E_MorningTruck = instance as E_MorningTruck
	if truck == null:
		instance.free()
		return null

	var zone_node: Node3D = self as Node as Node3D
	truck.transform = zone_node.global_transform.affine_inverse() * truck_parking.global_transform
	add_child(truck)
	_truck = truck
	truck.open_door()
	return truck


## Убирает только существующий runtime-узел; машина не зарегистрирована как Entity в World.
func clear_truck() -> void:
	if get_truck() != null:
		_truck.queue_free()
	_truck = null


## Читает упорядоченные маркеры кузова; legacy SpawnPoints нужны только сценам без стоянки.
func get_cargo_markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	var truck: E_MorningTruck = get_truck()
	if truck_parking != null:
		if truck != null:
			markers.assign(truck.cargo_slots.slice(0, DEF_ItemPlacement.MAX_CANDIDATES))
		return markers

	for child: Node in _spawn_points.get_children():
		var marker: Marker3D = child as Marker3D
		if marker != null:
			markers.append(marker)
			if markers.size() == DEF_ItemPlacement.MAX_CANDIDATES:
				break
	return markers
#endregion


#region Информация приёмки
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_status_remaining = maxf(0.0, _status_remaining - delta)
	if _status_remaining > 0.0:
		return
	_status_remaining = STATUS_REFRESH_SECONDS

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
	if cycle.phase == C_DayCycle.Phase.MORNING and truck_parking != null:
		var current_status: ReceivingShiftService.Status = ReceivingShiftService.status(cycle, self)
		_sign_label.text += "\n" + ("Разгрузка завершена" if current_status.reasons.is_empty() else "\n".join(current_status.reasons))
#endregion
