extends Node3D
## Minimal scene-side receiver showing how a valve signal can drive authored scene effects.

@onready var _off_bulb: MeshInstance3D = $OffBulb
@onready var _on_bulb: MeshInstance3D = $OnBulb
@onready var _light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	set_active(false)


func _process(_delta: float) -> void:
	var valve: E_InteractionTestValve = get_parent() as E_InteractionTestValve
	if valve != null:
		set_active(valve.is_active())


func set_active(active: bool) -> void:
	_off_bulb.visible = not active
	_on_bulb.visible = active
	_light.visible = active
