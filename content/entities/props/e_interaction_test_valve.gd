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
## Normalized actual value. Initial value and reset/restore changes do not activate gameplay.
signal progress_changed(progress: float)

@export var rotation_axis: Vector3 = Vector3.UP
@export var rotation_angle_degrees: float = 180.0

@export var mode: Mode = Mode.IMMEDIATE_E:
	set(value):
		mode = value
		if is_node_ready():
			_refresh_label()

@onready var _label: Label3D = $Label3D
@onready var _wheel: Node3D = $Wheel
@onready var _progress_label: Label3D = $ProgressStatus

var _rest_basis: Basis = Basis.IDENTITY
var _last_progress: float = -1.0

func _ready() -> void:
	_rest_basis = _wheel.basis
	_refresh_label()
	_sync_progress.call_deferred()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_sync_progress()


func define_components() -> Array[Component]:
	return [C_InteractionToggle.new()]


func activate() -> void:
	var state: C_InteractionToggle = get_component(C_InteractionToggle) as C_InteractionToggle
	state.active = not state.active
	_sync_progress()
	activated.emit(state.active)


func is_active() -> bool:
	var state: C_InteractionToggle = get_component(C_InteractionToggle) as C_InteractionToggle
	return state != null and state.active


func get_progress() -> float:
	if mode == Mode.IMMEDIATE_E:
		return 1.0 if is_active() else 0.0
	var action: DEF_InteractionTestValveAction = _mode_action()
	var progress: ProlongedInteractionProgress = ProlongedInteractionService.progress_for(self, action.action_id) if action != null else null
	return clampf(progress.fraction, 0.0, 1.0) if progress != null else 0.0


## Debug-only preview of retained progress; does not execute a hold completion effect.
func set_progress(value: float) -> bool:
	if not is_finite(value) or value < 0.0 or value > 1.0 or not EntityAvailability.contains(self, ECS.world):
		return false
	if mode == Mode.IMMEDIATE_E:
		if value != 0.0 and value != 1.0:
			return false
		if is_active() != (value == 1.0):
			activate()
	else:
		var action: DEF_InteractionTestValveAction = _mode_action()
		if action == null or not ProlongedInteractionService.debug_set_progress(self, action, value):
			return false
	_sync_progress()
	return true


func _mode_action() -> DEF_InteractionTestValveAction:
	var actions: C_InteractionActionSet = get_component(C_InteractionActionSet) as C_InteractionActionSet
	if actions != null:
		for candidate: DEF_InteractionAction in actions.actions:
			var action: DEF_InteractionTestValveAction = candidate as DEF_InteractionTestValveAction
			if action != null and action.mode == mode:
				return action
	return null


func _sync_progress() -> void:
	if Engine.is_editor_hint() or not is_node_ready():
		return
	var fraction: float = get_progress()
	var angle: float = deg_to_rad(rotation_angle_degrees) * fraction
	_wheel.basis = _rest_basis * Basis(rotation_axis.normalized(), angle) if not rotation_axis.is_zero_approx() else _rest_basis
	_progress_label.visible = DebugHudService.is_enabled()
	var action: DEF_InteractionTestValveAction = _mode_action()
	var remaining: float = (1.0 - fraction) * action.timing.duration_seconds if action != null and action.timing != null else 0.0
	_progress_label.text = "%d%% · %.1f с · %s" % [roundi(fraction * 100.0), remaining, "включён" if is_active() else "выключен"]
	if not is_equal_approx(_last_progress, fraction):
		_last_progress = fraction
		progress_changed.emit(fraction)


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
