extends Node3D
## Projects authored presence cues; native process-clock Tweens own blending, not GameClock.
## Gameplay remains read-only; suspend cancels presentation at explicit lifecycle boundaries.
class_name NpcNightPresentation

## Shared immutable audio/shadow tuning for this authored view.
@export var definition: DEF_NpcNightPresentation

const SILENT_VOLUME_DB: float = -60.0

@onready var _music: AudioStreamPlayer3D = $Music
@onready var _shadow: Decal = $Shadow

var _transition: Tween
var _music_enabled: bool = false
var _shadow_enabled: bool = false
var _hunting: bool = false


#region Native view lifecycle
func _ready() -> void:
	assert(definition != null, "Night presence requires authored presentation tuning")
	var actor: E_DistrictNpc = get_parent() as E_DistrictNpc
	actor.role_cleanup_requested.connect(_on_role_cleanup)
	_music.finished.connect(_on_music_finished)
	suspend()


func _exit_tree() -> void:
	_cancel_transition()


func _on_role_cleanup(_request: NpcRoleCleanupRequest) -> void:
	suspend()


func _on_music_finished() -> void:
	if _music_enabled:
		_music.play()


func _cancel_transition() -> void:
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = null
#endregion


#region Committed presentation projection
## Applies selected appearance cues and committed combat intensity without touching AI state.
func synchronize(music_enabled: bool, shadow_enabled: bool, hunting: bool) -> void:
	if (
		music_enabled == _music_enabled
		and shadow_enabled == _shadow_enabled and hunting == _hunting
	):
		return
	if not music_enabled and not shadow_enabled:
		suspend()
		return

	_cancel_transition()
	_music_enabled = music_enabled
	_shadow_enabled = shadow_enabled
	_hunting = hunting
	_music.max_distance = definition.music_distance
	if music_enabled:
		if not _music.playing:
			_music.volume_db = SILENT_VOLUME_DB
			_music.play()
	else:
		_music.stop()

	_shadow.visible = shadow_enabled
	_transition = create_tween().set_parallel(true)
	if music_enabled:
		var volume: float = (
			definition.hunting_volume_db if hunting else definition.presence_volume_db
		)
		_transition.tween_property(_music, "volume_db", volume, definition.fade_seconds)
	var opacity: float = 0.0
	if shadow_enabled:
		opacity = (
			definition.hunting_shadow_opacity if hunting else definition.presence_shadow_opacity
		)
	_transition.tween_property(_shadow, "modulate:a", opacity, definition.fade_seconds)


## Clears native work immediately before dormancy, reset, death or profile replacement.
func suspend() -> void:
	_cancel_transition()
	_music_enabled = false
	_shadow_enabled = false
	_hunting = false
	_music.stop()
	_music.volume_db = SILENT_VOLUME_DB
	_shadow.visible = false
	_shadow.modulate.a = 0.0
#endregion
