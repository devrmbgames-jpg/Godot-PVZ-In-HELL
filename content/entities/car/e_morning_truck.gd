extends CharacterBody3D
## Статичная утренняя машина: авторские грузовые места и существующая анимация двери.
class_name E_MorningTruck

## Упорядоченные места груза; проверяются первые 16, включая авторские верхние позиции.
@export var cargo_slots: Array[Marker3D] = []
## Авторская область кузова для последующей разгрузки и обратного груза.
@export var cargo_area: Area3D = null
## Существующий проигрыватель двери без анимации прибытия автомобиля.
@export var door_animation: AnimationPlayer = null
## Общая проверка полной формы, опоры и допустимой укладки на другие коробки.
@export var placement: DEF_ItemPlacement = preload("res://content/definitions/gameplay/deliveries/def_truck_cargo_placement.tres")

## Предельная длительность закрытия вне кузова; сбой/зацикливание анимации не удерживает машину.
@export_range(0.1, 10.0, 0.1) var departure_timeout_seconds: float = 2.0

var _created_frame: int = -1
var _departing: bool = false
var _waiting_for_player: bool = false
var _closing_elapsed: float = 0.0
var _departure_players: Array[WeakRef] = []
@onready var _cargo_shape: CollisionShape3D = cargo_area.get_node_or_null("CollisionShape3D") as CollisionShape3D if cargo_area != null else null


#region Дверь и готовность кузова
func _ready() -> void:
	_created_frame = Engine.get_physics_frames()
	set_physics_process(false)


## Открывает существующую дверь; положение автомобиля остаётся авторским.
func open_door() -> void:
	if is_instance_valid(door_animation):
		door_animation.play(&"door_open")


## Ждёт синхронизации коллайдеров нового автомобиля с физическим пространством.
func is_ready_for_loading() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and not _departing and Engine.get_physics_frames() > _created_frame
#endregion

#region Текущие границы грузовой области
## Проверяет авторскую область; неверная настройка запрещает отправление.
func has_cargo_volume() -> bool:
	return is_instance_valid(_cargo_shape) and not _cargo_shape.disabled and _cargo_shape.shape is BoxShape3D


## Консервативно проверяет твёрдые формы в локальных осях кузова, без устаревающего списка Area.
func overlaps_cargo(body: PhysicsBody3D) -> bool:
	if not has_cargo_volume() or not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
		return false
	var volume: AABB = (_cargo_shape.shape as BoxShape3D).get_debug_mesh().get_aabb()
	var relative_pose: Transform3D = _cargo_shape.global_transform.affine_inverse() * body.global_transform
	for owner_id: int in body.get_shape_owners():
		if body.is_shape_owner_disabled(owner_id):
			continue
		var shape_pose: Transform3D = relative_pose * body.shape_owner_get_transform(owner_id)
		for shape_index: int in body.shape_owner_get_shape_count(owner_id):
			var shape: Shape3D = body.shape_owner_get_shape(owner_id, shape_index)
			if shape != null and volume.intersects(shape_pose * shape.get_debug_mesh().get_aabb()):
				return true
	return false
#endregion


#region Конечное закрытие и исчезновение
## Читает временное состояние отправления; повторная команда не перезапускает дверь.
func is_departing() -> bool:
	return _departing


## Начинает один lifecycle; игроки наблюдаются слабыми ссылками без удержания узлов.
func request_departure(players: Array[PhysicsBody3D]) -> void:
	if _departing or is_queued_for_deletion():
		return
	_departure_players.clear()
	for player_body: PhysicsBody3D in players:
		if is_instance_valid(player_body):
			_departure_players.append(weakref(player_body))
	_departing = true
	_waiting_for_player = true
	_closing_elapsed = 0.0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _departing or is_queued_for_deletion():
		return
	for reference: WeakRef in _departure_players:
		var player_body: PhysicsBody3D = reference.get_ref() as PhysicsBody3D
		if overlaps_cargo(player_body):
			if not _waiting_for_player:
				_hold_door_open()
			_waiting_for_player = true
			_closing_elapsed = 0.0
			return

	if _waiting_for_player:
		_waiting_for_player = false
		if is_instance_valid(door_animation) and door_animation.has_animation(&"door_close"):
			door_animation.play(&"door_close")
	_closing_elapsed += maxf(0.0, delta)

	if not is_instance_valid(door_animation) or not door_animation.is_playing() or _closing_elapsed >= departure_timeout_seconds:
		queue_free()


func _hold_door_open() -> void:
	if is_instance_valid(door_animation) and door_animation.has_animation(&"door_open"):
		door_animation.play(&"door_open")
		door_animation.seek(door_animation.get_animation(&"door_open").length, true)
		door_animation.stop(true)
#endregion
