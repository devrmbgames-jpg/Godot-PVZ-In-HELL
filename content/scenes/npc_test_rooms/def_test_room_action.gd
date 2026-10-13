@tool
extends DEF_InteractionAction
## Authored test-room portal action; the native session owner handles deferred scene replacement.
class_name DEF_TestRoomAction

## Canonical room key; empty returns to the test hall. It is immutable during gameplay.
@export var room_key: StringName = &""


#region Native interaction
func is_available(actor: Entity, _source: Entity, _target: Entity) -> bool:
	if not actor.has_component(C_PlayerInputController):
		return false
	var root: Node = actor.get_tree().current_scene
	return (
		root != null
		and (
			root.scene_file_path == GameSessionService.TEST_LEVEL
			or GameSessionService.is_test_room(root.scene_file_path)
		)
	)


func execute(actor: Entity, _source: Entity, _target: Entity) -> void:
	GameSessionService.request_test_room(actor.get_tree().current_scene, room_key)


func complete(actor: Entity, source: Entity, target: Entity) -> bool:
	if not is_available(actor, source, target):
		return false
	return GameSessionService.request_test_room(actor.get_tree().current_scene, room_key) == OK
#endregion
