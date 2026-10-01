extends Node3D
## Local-player presentation overlay; neither NPC identity nor physics is replaced.
class_name HungerNpcVisual

@export var normal_visual_path: NodePath = NodePath("../Body")
@export var normal_message_path: NodePath = NodePath("../Message")
@onready var _normal: Node3D = get_node_or_null(normal_visual_path) as Node3D
@onready var _message: Node3D = get_node_or_null(normal_message_path) as Node3D
@onready var _food: Node3D = $Food

var _applied: bool = false
var _normal_was_visible: bool = true
var _message_was_visible: bool = true


func _process(_delta: float) -> void:
	var starving: bool = HungerService.tier(HungerService.player_state()) == C_Hunger.Tier.STARVING
	if starving == _applied:
		return
	if starving:
		_normal_was_visible = _normal.visible if _normal != null else false
		_message_was_visible = _message.visible if _message != null else false
		if _normal != null:
			_normal.visible = false
		if _message != null:
			_message.visible = false
		_food.visible = true
	else:
		_restore()
	_applied = starving


func _exit_tree() -> void:
	if _applied:
		_restore()


func _restore() -> void:
	if is_instance_valid(_normal):
		_normal.visible = _normal_was_visible
	if is_instance_valid(_message):
		_message.visible = _message_was_visible
	if is_instance_valid(_food):
		_food.visible = false
