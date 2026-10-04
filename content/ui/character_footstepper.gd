extends Footstepper
## Адаптер ручного Footstepper для RigidBody-NPC; безопасно приводит родителя к CharacterBody3D.
## Ручные звуки вызываются CharacterFeedback; сторонний аддон сохраняет свой контракт.
class_name CharacterFootstepper

#region Совместимость ручного режима
func _check_parent() -> void:
	if is_manual:
		parent = get_parent() as CharacterBody3D
		return

	super._check_parent()
#endregion

#region Освобождение аудио
func _exit_tree() -> void:
	# Активный native playback останавливается до удаления движущегося персонажа или закрытия дерева.
	available_players.clear()
	for audio_node: Node in get_children():
		var spatial_player: AudioStreamPlayer3D = audio_node as AudioStreamPlayer3D
		var flat_player: AudioStreamPlayer = audio_node as AudioStreamPlayer
		if spatial_player != null:
			if spatial_player.playing:
				spatial_player.get_stream_playback().stop()
			spatial_player.stop()
			spatial_player.stream = null
			available_players.append(spatial_player)
		elif flat_player != null:
			if flat_player.playing:
				flat_player.get_stream_playback().stop()
			flat_player.stop()
			flat_player.stream = null
			available_players.append(flat_player)
#endregion
