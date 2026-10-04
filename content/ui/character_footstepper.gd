extends Footstepper
## Addon manual mode assigns an arbitrary parent to a CharacterBody3D field.
## Keep the addon read-only and allow its manual audio API under rigid NPC presentation.
class_name CharacterFootstepper

#region Addon compatibility
func _check_parent() -> void:
	if is_manual:
		parent = get_parent() as CharacterBody3D
		return
	super._check_parent()
#endregion

#region Audio lifetime
func _exit_tree() -> void:
	# Release active native playbacks before shutdown or removal of a moving character.
	available_players.clear()
	for audio_node: Node in get_children():
		var spatial_player: AudioStreamPlayer3D = audio_node as AudioStreamPlayer3D
		var flat_player: AudioStreamPlayer = audio_node as AudioStreamPlayer
		if spatial_player != null:
			spatial_player.stop()
			spatial_player.stream = null
			available_players.append(spatial_player)
		elif flat_player != null:
			flat_player.stop()
			flat_player.stream = null
			available_players.append(flat_player)
#endregion
