extends Node
## Представление принятого урона: звук, экранное предупреждение и мировые метки; Health не изменяет.
class_name DamageFeedbackView

## Получатель локальных экранных предупреждений по совпадению стабильного ID.
@export var player: Entity = null
## Источник уже принятых DamageFeedback; подключается через bind_observer.
@export var observer: O_DamageFeedback = null
## Разрешает представление; отключение очищает предупреждения и метки.
@export var enabled: bool = true
## Разрешает синтезированные звуки попадания.
@export var sound_enabled: bool = true
## Отключает цветовую заливку и подъём меток, сохраняя текст.
@export var reduced_motion: bool = true
## Длительность локального предупреждения в секундах.
@export_range(0.1, 5.0) var player_warning_seconds: float = 0.8
## Время жизни мировой метки в секундах.
@export_range(0.1, 5.0) var world_label_seconds: float = 1.2
## Предел мировых меток; при переполнении удаляется самая старая.
@export_range(1, 32) var maximum_world_labels: int = 12
## Цвет обычного физического урона.
@export var damage_color: Color = Color(1.0, 0.3, 0.25)
## Цвет токсичного урона.
@export var toxic_color: Color = Color(0.3, 1.0, 0.55)
## Цвет взрывного урона.
@export var explosion_color: Color = Color(1.0, 0.7, 0.2)
## Цвет предупреждения об огне; текст остаётся видимым при уменьшенном движении.
@export var fire_color: Color = Color(1.0, 0.4, 0.05)

const SAMPLE_RATE: int = 22050
const PEAK_SAMPLE: float = 32767.0
const SOUND_GAIN: float = 0.2
const WARNING_TINT_ALPHA: float = 0.08
const LABEL_HEIGHT: float = 0.35
const LABEL_RISE_SPEED: float = 0.18
const WARNING_NAMES: Array[String] = ["Ранение", "Ближняя атака", "Удар", "Взрыв", "Токсичная зона", "Протечка", "Попадание", "Огненная аура"]

var _remaining: float = 0.0
var _labels: Array[Label3D] = []
var _label_times: Array[float] = []
var _tones: Array[AudioStreamWAV] = []
@onready var _warning: Label = $Warning
@onready var _tint: ColorRect = $Tint
@onready var _sound: AudioStreamPlayer = $Sound


#region Источник и жизненный цикл
func _ready() -> void:
	_tones = [_tone(520.0, 0.09), _tone(240.0, 0.15), _tone(140.0, 0.22)]
	bind_observer()
	_clear_warning()


## Подключает текущий источник один раз; вызывается при готовности или после назначения observer.
func bind_observer() -> void:
	if observer != null and not observer.received.is_connected(_on_feedback):
		observer.received.connect(_on_feedback)


func _exit_tree() -> void:
	if is_instance_valid(observer) and observer.received.is_connected(_on_feedback):
		observer.received.disconnect(_on_feedback)
	_clear_labels()


func _process(delta: float) -> void:
	if not enabled:
		_clear_warning()
		_clear_labels()
		return
	if not sound_enabled:
		_sound.stop()
	_remaining = maxf(0.0, _remaining - delta)
	_warning.visible = _remaining > 0.0
	_tint.visible = _remaining > 0.0 and not reduced_motion
	_tint.color.a = WARNING_TINT_ALPHA * clampf(_remaining / player_warning_seconds, 0.0, 1.0)
	for index: int in range(_labels.size() - 1, -1, -1):
		_label_times[index] -= delta
		if _label_times[index] <= 0.0 or not is_instance_valid(_labels[index]):
			if is_instance_valid(_labels[index]):
				_labels[index].queue_free()
			_labels.remove_at(index)
			_label_times.remove_at(index)
			continue

		_labels[index].modulate.a = clampf(_label_times[index] / world_label_seconds, 0.0, 1.0)
		if not reduced_motion:
			_labels[index].position.y += delta * LABEL_RISE_SPEED


#endregion

#region Представление результата
func _on_feedback(feedback: DamageFeedback) -> void:
	if not enabled or feedback == null:
		return

	var tint: Color = _color(feedback.damage_type)
	if feedback.audience == DamageFeedback.Audience.PLAYER:
		if not is_instance_valid(player) or feedback.target_id != player.id:
			return

		_remaining = player_warning_seconds
		_warning.text = "%s · −%.0f HP" % [WARNING_NAMES[feedback.damage_type], feedback.amount]
		_warning.modulate = tint
		_tint.color = tint
		if sound_enabled:
			var tone: int = 1 if feedback.damage_type == DamageRequest.Type.TOXIC else 2 if feedback.damage_type == DamageRequest.Type.EXPLOSION else 0
			_sound.stream = _tones[tone]
			_sound.play()
		return
	if feedback.audience != DamageFeedback.Audience.PACKAGE and not feedback.actor_is_player:
		return
	if _labels.size() >= maximum_world_labels:
		var oldest: Label3D = _labels.pop_front() as Label3D
		if is_instance_valid(oldest):
			oldest.queue_free()
		_label_times.pop_front()

	var label: Label3D = Label3D.new()
	label.name = "WorldDamageLabel"
	label.text = "%s −%.0f" % ["Посылка" if feedback.audience == DamageFeedback.Audience.PACKAGE else "", feedback.amount]
	label.font_size = 40
	label.pixel_size = 0.003
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	add_child(label, true)
	label.global_position = feedback.position + Vector3.UP * LABEL_HEIGHT
	_labels.append(label)
	_label_times.append(world_label_seconds)


#endregion

#region Диагностика и визуальные ресурсы
## Текст фактических настроек и таймеров представления для отладочного HUD.
func debug_text() -> String:
	return "FEEDBACK · %s · звук %s\nТаймер предупреждения %.2f / %.2f с\nМетки урона %d / %d · время %.2f с\nДвижение: %s · задача: выйдите из опасной зоны" % ["вкл" if enabled else "выкл", "вкл" if sound_enabled else "выкл", _remaining, player_warning_seconds, _labels.size(), maximum_world_labels, world_label_seconds, "снижено" if reduced_motion else "обычное"]


func _color(kind: DamageRequest.Type) -> Color:
	return toxic_color if kind == DamageRequest.Type.TOXIC else explosion_color if kind == DamageRequest.Type.EXPLOSION else fire_color if kind == DamageRequest.Type.FIRE else damage_color


func _clear_warning() -> void:
	_remaining = 0.0
	_warning.visible = false
	_tint.visible = false
	_sound.stop()


func _clear_labels() -> void:
	for label: Label3D in _labels:
		if is_instance_valid(label):
			label.queue_free()
	_labels.clear()
	_label_times.clear()


func _tone(frequency: float, seconds: float) -> AudioStreamWAV:
	var count: int = int(SAMPLE_RATE * seconds)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(count * 2)
	for index: int in count:
		var envelope: float = sin(PI * float(index) / count)
		var wave: float = sin(TAU * frequency * index / SAMPLE_RATE)
		samples.encode_s16(index * 2, int(PEAK_SAMPLE * SOUND_GAIN * envelope * wave))

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = samples
	return stream

#endregion
