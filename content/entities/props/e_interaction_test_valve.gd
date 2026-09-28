@tool
extends Entity
## Scene-authored R11.1 interaction demo trigger.
class_name E_InteractionTestValve

enum Mode {
	IMMEDIATE_E,
	HOLD_DECAY,
	HOLD_INSTANT,
	HOLD_ON_COMPLETE,
	HOLD_NEVER,
}

signal activated(active: bool)

@export var mode: Mode = Mode.IMMEDIATE_E:
	set(value):
		mode = value
		if is_node_ready():
			_refresh_label()

var _active: bool = false
@onready var _label: Label3D = $Label3D


func _ready() -> void:
	_refresh_label()


func activate() -> void:
	_active = not _active
	activated.emit(_active)


func is_active() -> bool:
	return _active


func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	match mode:
		Mode.IMMEDIATE_E:
			_label.text = "E · PRESS"
		Mode.HOLD_DECAY:
			_label.text = "F HOLD · DECAY"
		Mode.HOLD_INSTANT:
			_label.text = "F HOLD · INSTANT"
		Mode.HOLD_ON_COMPLETE:
			_label.text = "F HOLD · ON_COMPLETE"
		Mode.HOLD_NEVER:
			_label.text = "F HOLD · NEVER"
