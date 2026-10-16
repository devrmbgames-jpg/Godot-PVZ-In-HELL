extends Node3D
## Projects the NPC's message onto an authored physical sign; gameplay remains read-only.
class_name NpcSignboard

## Higher role composition may supply text without coupling this native view to its state.
signal text_requested(request: NpcSignTextRequest)

## Presentation-only phases, also available to a future scratching animation adapter.
enum Phase { HIDDEN, ERASING, WRITING, READABLE }

## Emitted when presentation changes phase; never commits a dialogue or service action.
signal phase_changed(phase: Phase)

## Seconds spent erasing the previous line when a different communication replaces it.
@export_range(0.01, 5.0, 0.01) var erase_seconds: float = 0.25
## Seconds spent gradually revealing one complete communication, independent of its length.
@export_range(0.01, 10.0, 0.01) var write_seconds: float = 1.2

@onready var _text: Label3D = $Text
@onready var _actor: E_DistrictNpc = get_parent() as E_DistrictNpc
@onready var _message: Label3D = _actor.get_node("Message") as Label3D

var _replaced_message: bool = false
var _phase: Phase = Phase.HIDDEN
var _intent_id: StringName = &""
var _target_text: String = ""
var _erasing_text: String = ""
var _elapsed: float = 0.0


#region Native presentation lifecycle
func _ready() -> void:
	_actor.role_cleanup_requested.connect(_on_role_cleanup)
	_suspend()


func _process(delta: float) -> void:
	if (
		not EntityAvailability.contains(_actor, ECS.world)
		or _actor.has_component(C_Death) or not NpcDialogueService.uses_signboard(_actor)
	):
		_suspend()
		return
	_message.visible = false
	_replaced_message = true
	var request: NpcSignTextRequest = NpcSignTextRequest.new()
	text_requested.emit(request)
	var requested_text: String = request.text.strip_edges()
	if requested_text.is_empty():
		_hide_board()
		return
	if _target_text != requested_text or _intent_id != request.intent_id:
		# An ended source must not remain readable while an unrelated request starts writing.
		if _intent_id != request.intent_id:
			_text.text = ""
		_target_text = requested_text
		_intent_id = request.intent_id
		_erasing_text = _text.text
		_elapsed = 0.0
		visible = true
		_set_phase(Phase.WRITING if _erasing_text.is_empty() else Phase.ERASING)
	_advance_writing(delta)


## Reads the current presentation phase without exposing mutable gameplay or a second clock.
func phase() -> Phase:
	return _phase


func _on_role_cleanup(_request: NpcRoleCleanupRequest) -> void:
	_suspend()


func _suspend() -> void:
	if _replaced_message:
		_message.visible = true
		_replaced_message = false
	_hide_board()


func _hide_board() -> void:
	visible = false
	_text.text = ""
	_target_text = ""
	_erasing_text = ""
	_intent_id = &""
	_elapsed = 0.0
	_set_phase(Phase.HIDDEN)
#endregion


#region Presentation-only writing
func _advance_writing(delta: float) -> void:
	if _phase not in [Phase.ERASING, Phase.WRITING]:
		return
	_elapsed += maxf(delta, 0.0)
	if _phase == Phase.ERASING:
		var remaining: float = 1.0 - clampf(_elapsed / erase_seconds, 0.0, 1.0)
		_text.text = _erasing_text.substr(0, ceili(_erasing_text.length() * remaining))
		if remaining <= 0.0:
			_elapsed = 0.0
			_erasing_text = ""
			_set_phase(Phase.WRITING)
	elif _phase == Phase.WRITING:
		var progress: float = clampf(_elapsed / write_seconds, 0.0, 1.0)
		_text.text = _target_text.substr(0, floori(_target_text.length() * progress))
		if progress >= 1.0:
			_set_phase(Phase.READABLE)


func _set_phase(next_phase: Phase) -> void:
	if _phase != next_phase:
		_phase = next_phase
		phase_changed.emit(_phase)
#endregion
