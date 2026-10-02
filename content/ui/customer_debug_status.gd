extends Label3D

const REFRESH_SECONDS: float = 0.1

var _remaining: float = 0.0
@onready var _customer: E_Customer = get_parent() as E_Customer


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = REFRESH_SECONDS
		text = CustomerDebugPresentation.text_for(_customer)
		visible = not text.is_empty()
