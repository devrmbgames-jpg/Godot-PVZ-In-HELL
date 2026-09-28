extends Node3D
## Minimal scene-side receiver for an interaction trigger signal.

@onready var _off_bulb: MeshInstance3D = $OffBulb
@onready var _on_bulb: MeshInstance3D = $OnBulb
@onready var _light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	set_active(false)


func set_active(active: bool) -> void:
	_off_bulb.visible = not active
	_on_bulb.visible = active
	_light.visible = active
