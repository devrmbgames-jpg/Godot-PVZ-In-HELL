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

var _created_frame: int = -1

#region Дверь и готовность кузова
func _ready() -> void:
	_created_frame = Engine.get_physics_frames()


## Открывает существующую дверь; положение автомобиля остаётся авторским.
func open_door() -> void:
	if is_instance_valid(door_animation):
		door_animation.play(&"door_open")


## Ждёт синхронизации коллайдеров нового автомобиля с физическим пространством.
func is_ready_for_loading() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and Engine.get_physics_frames() > _created_frame
#endregion
