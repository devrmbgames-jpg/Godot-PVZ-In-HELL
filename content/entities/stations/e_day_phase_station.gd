@tool
extends Entity
class_name E_DayPhaseStation

@export var sleep_station: bool = false


func _ready() -> void:
	var sign_label: Label3D = get_node_or_null("Sign") as Label3D
	if sign_label != null:
		sign_label.text = "ОТДЫХ\nСон до утра" if sleep_station else "СМЕНА\nНачать / завершить"
