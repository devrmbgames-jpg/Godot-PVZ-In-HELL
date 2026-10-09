extends Node3D
## При голоде локального игрока заменяет вид NPC пищевым образом; личность и физика сохраняются.
class_name HungerNpcVisual

## Путь обычного вида NPC, временно скрываемого при хищном восприятии.
@export var normal_visual_path: NodePath = NodePath("../Body")
## Путь обычной надписи, скрываемой вместе с видом; прежняя видимость восстанавливается.
@export var normal_message_path: NodePath = NodePath("../Message")
@onready var _normal: Node3D = get_node_or_null(normal_visual_path) as Node3D
@onready var _message: Node3D = get_node_or_null(normal_message_path) as Node3D
@onready var _food: Node3D = $Food

var _applied: bool = false
var _normal_was_visible: bool = true
var _message_was_visible: bool = true


#region Переключение образа
func _process(_delta: float) -> void:
	var sees_food: bool = HungerRules.sees_npcs_as_food(HungerService.player_state())
	if sees_food == _applied:
		return
	if sees_food:
		_normal_was_visible = _normal.visible if _normal != null else false
		_message_was_visible = _message.visible if _message != null else false
		if _normal != null:
			_normal.visible = false
		if _message != null:
			_message.visible = false
		_food.visible = true
	else:
		_restore()
	_applied = sees_food


#endregion

#region Восстановление видимости
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

#endregion
