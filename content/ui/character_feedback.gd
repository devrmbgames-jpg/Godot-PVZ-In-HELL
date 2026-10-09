extends Node3D
## Звуки шагов и локальное покачивание камеры по фактическому движению; физику и крепления головы не исполняет.
class_name CharacterFeedback

## Разрешает звук по пересечениям фазы фактических шагов.
@export var footsteps_enabled: bool = true
## Создаёт 3D-проигрыватели Footstepper вместо локального аудио.
@export var spatial_audio: bool = false
## Громкость шагов в децибелах.
@export_range(-80.0, 0.0, 1.0) var volume_db: float = -14.0
## Горизонтальное расстояние между звуками шагов в метрах.
@export_range(0.2, 4.0, 0.1) var step_distance: float = 2.8
## Разрешает производное покачивание камеры при ходьбе.
@export var bob_enabled: bool = true
## Локально отключает покачивание; игрок дополнительно учитывает общую настройку.
@export var reduced_motion: bool = false
## Путь камеры относительно физического персонажа; исходное смещение восстанавливается при выходе.
@export var camera_path: NodePath = NodePath("HeadY/HeadX/HeadRoot/Camera3D")
## Амплитуда горизонтального/вертикального смещения камеры в метрах.
@export var bob_amplitude: Vector2 = Vector2(0.006, 0.012)
## Скорость экспоненциального сглаживания покачивания, 1/с.
@export_range(1.0, 30.0, 1.0) var bob_response: float = 12.0

const MINIMUM_WALK_SPEED: float = 0.2
const MAXIMUM_FRAME_TRAVEL: float = 3.0
const MINIMUM_DISTANCE: float = 0.1
const PHASE_EPSILON: float = 0.000001

var _actor: E_PhysicalCharacter = null
var _camera: Camera3D = null
var _camera_rest: Vector3 = Vector3.ZERO
var _camera_offset: Vector3 = Vector3.ZERO
var _previous_position: Vector3 = Vector3.ZERO
var _bob_phase: float = PI / 2.0
@onready var _footsteps: Footstepper = $Footstepper


#region Подготовка и восстановление
func _enter_tree() -> void:
	# Настройки задаются до создания аудиопроигрывателей в _ready аддона.
	var footsteps: Footstepper = get_node("Footstepper") as Footstepper
	footsteps.audio_is_3d = spatial_audio
	footsteps.audio_volume = volume_db


func _ready() -> void:
	_actor = get_parent() as E_PhysicalCharacter
	if _actor == null:
		return

	_previous_position = (_actor as Node as Node3D).global_position
	_bob_phase = PI / 2.0
	_camera = _actor.get_node_or_null(camera_path) as Camera3D
	if _camera != null:
		_camera_rest = _camera.position


func _exit_tree() -> void:
	if is_instance_valid(_camera):
		_camera.position = _camera_rest


#endregion

#region Шаги и покачивание
func _physics_process(delta: float) -> void:
	if _actor == null or not EntityAvailability.contains(_actor, ECS.world) or delta <= 0.0:
		return

	var position: Vector3 = (_actor as Node as Node3D).global_position
	var difference: Vector3 = position - _previous_position
	_previous_position = position
	var distance: float = Vector2(difference.x, difference.z).length()
	var motion: C_Motion = _actor.get_component(C_Motion) as C_Motion
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	var allowed: bool = motion != null and motion.is_on_floor and motion.control_enabled and not _actor.has_component(C_Death)
	allowed = allowed and controller != null and not controller.direction_motion.is_zero_approx()
	allowed = allowed and InteractionControlFocus.current(_actor) < InteractionControlFocus.Priority.MODAL
	allowed = allowed and CartTransportService.current(_actor) == null

	var walking: bool = allowed and distance < MAXIMUM_FRAME_TRAVEL and distance / delta >= MINIMUM_WALK_SPEED
	if walking:
		# Одна фаза: PI на шаг; звук и нижняя точка камеры совпадают.
		var next_phase: float = _bob_phase + PI * distance / maxf(step_distance, MINIMUM_DISTANCE)
		var strikes: int = int(floor((next_phase + PHASE_EPSILON) / PI)) - int(floor((_bob_phase + PHASE_EPSILON) / PI))
		_bob_phase = fposmod(next_phase, TAU)
		if footsteps_enabled:
			for strike: int in strikes:
				_footsteps.play_footstep()
	else:
		_bob_phase = PI / 2.0

	var target: Vector3 = Vector3.ZERO
	if walking and bob_enabled and not reduced_motion and not (_actor.has_component(C_PlayerInputController) and bool(GameSettingsService.value("reduced_motion"))):
		target = Vector3(sin(_bob_phase) * bob_amplitude.x, -cos(_bob_phase * 2.0) * bob_amplitude.y, 0.0)
	_camera_offset = _camera_offset.lerp(target, 1.0 - exp(-bob_response * delta))
	if _camera != null:
		_camera.position = _camera_rest + _camera_offset

#endregion
