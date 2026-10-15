extends Label3D
## Читает CustomerDebugPresentation с номинальным интервалом 0.1 секунды process delta.

const REFRESH_SECONDS: float = 0.1

var _remaining: float = 0.0
@onready var _customer: E_NpcCharacter = get_parent() as E_NpcCharacter


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = REFRESH_SECONDS
		text = CustomerDebugPresentation.text_for(_customer)
		visible = not text.is_empty()
