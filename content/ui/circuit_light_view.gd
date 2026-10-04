extends Node
## Light3D child: event-driven visual clock, never changes the gameplay switch state.
class_name CircuitLightView

@export var circuit_id: StringName = &"warehouse"

var _observer: O_LightFlicker = null
var _world: World = null
var _remaining: float = 0.0
var _elapsed: float = 0.0
var _interval: float = LightFlickerEvent.DEFAULT_INTERVAL_SECONDS
var _request_id: StringName = &""
@onready var _light: Light3D = get_parent() as Light3D


func _ready() -> void:
	_bind_observer()


func _process(delta: float) -> void:
	_bind_observer()
	if not is_instance_valid(ECS.world) or _light == null:
		return

	var state: C_LightCircuit = LightCircuitService.state_for(circuit_id)
	if state == null:
		_remaining = 0.0
		return
	if not state.enabled:
		_remaining = 0.0
	else:
		_elapsed += maxf(0.0, delta)
		_remaining = maxf(0.0, _remaining - maxf(0.0, delta))
	_light.visible = state.enabled and is_lit()


func _exit_tree() -> void:
	_disconnect()


func is_lit() -> bool:
	return _remaining <= 0.0 or int(_elapsed / _interval) % 2 == 0


func cancel_flicker() -> void:
	_remaining = 0.0
	_request_id = &""


func _bind_observer() -> void:
	if is_instance_valid(_observer) and _world == ECS.world:
		return

	_disconnect()
	_world = ECS.world
	if not is_instance_valid(_world):
		return

	for observer: Observer in _world.observers:
		var relay: O_LightFlicker = observer as O_LightFlicker
		if relay != null:
			_observer = relay
			_observer.flickering_light.connect(_on_flicker)
			return


func _disconnect() -> void:
	if is_instance_valid(_observer) and _observer.flickering_light.is_connected(_on_flicker):
		_observer.flickering_light.disconnect(_on_flicker)
	_observer = null
	_world = null
	_remaining = 0.0


func _on_flicker(event: LightFlickerEvent) -> void:
	if event.circuit_id != circuit_id:
		return
	if event.kind == LightFlickerEvent.Kind.STOP:
		if event.request_id == _request_id:
			cancel_flicker()
		return
	if not is_finite(event.duration_seconds) or event.duration_seconds <= 0.0 or not is_finite(event.interval_seconds) or event.interval_seconds <= 0.0:
		return

	_request_id = event.request_id
	_remaining = event.duration_seconds
	_elapsed = 0.0
	_interval = event.interval_seconds
