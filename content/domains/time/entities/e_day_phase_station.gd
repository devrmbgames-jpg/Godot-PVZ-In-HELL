@tool
extends Entity
## Тонкое представление станции смены/сна; переходы задаются её действиями.
class_name E_DayPhaseStation

## Настраивает подпись станции сна вместо станции управления сменой.
@export var sleep_station: bool = false

const REFRESH_SECONDS: float = 0.25
var _remaining: float = 0.0
@onready var _sign: Label3D = get_node_or_null("Sign") as Label3D


func _ready() -> void:
	var sign_label: Label3D = get_node_or_null("Sign") as Label3D
	if sign_label != null:
		sign_label.text = "ОТДЫХ\nСон до утра" if sleep_station else "СМЕНА\nНачать / завершить"


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or sleep_station or _sign == null:
		return

	_remaining -= delta
	if _remaining > 0.0:
		return

	_remaining = REFRESH_SECONDS
	var status: String = DayPhaseService.shift_status(DayPhaseQueries.current())
	_sign.text = "СМЕНА\nНачать / завершить" + ("\n" + status if not status.is_empty() else "")
