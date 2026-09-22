extends Node

const SAMPLE_RATE: int = 22050
const BEEP_SECONDS: float = 0.12
const BEEP_FREQUENCY: float = 1200.0
const FEEDBACK_SECONDS: float = 5.0

@onready var label: Label3D = $Result
@onready var beep: AudioStreamPlayer3D = $Beep
@onready var _icon_mesh: MeshInstance3D = $IconOK
@onready var _clear_timer: Timer = $Timer
var _remaining: float = 0.0


#region Lifecycle
func _ready() -> void:
	var scanner: E_Scanner = get_parent() as E_Scanner
	scanner.scan_feedback.connect(_on_scan_feedback)
	beep.stream = _make_beep()
	label.visible = false
	_icon_mesh.visible = false



#endregion


#region Presentation
func _on_scan_feedback(result: PackageScanResult) -> void:
	label.text = "№%03d" % result.number
	label.visible = true
	_icon_mesh.visible = true
	
	if result.outcome != PackageScanResult.Outcome.REJECTED:
		beep.pitch_scale = 1.0 if result.outcome == PackageScanResult.Outcome.REGISTERED else 0.8
		beep.play()
	
	match result.outcome :
		PackageScanResult.Outcome.REJECTED :
			(_icon_mesh.material_override as BaseMaterial3D).emission = Color.ORANGE
			label.modulate = Color.ORANGE
		PackageScanResult.Outcome.REGISTERED :
			(_icon_mesh.material_override as BaseMaterial3D).emission = Color.LIGHT_GREEN
			label.modulate = Color.LIGHT_GREEN
		PackageScanResult.Outcome.ALREADY_REGISTERED :
			(_icon_mesh.material_override as BaseMaterial3D).emission = Color.DARK_GRAY
			label.modulate = Color.DARK_GRAY
	
	_clear_timer.start(FEEDBACK_SECONDS)


func _make_beep() -> AudioStreamWAV:
	var sample_count: int = int(SAMPLE_RATE * BEEP_SECONDS)
	var samples: PackedByteArray = PackedByteArray()
	samples.resize(sample_count * 2)
	for sample_index: int in sample_count:
		var envelope: float = sin(PI * float(sample_index) / sample_count)
		var amplitude: float = sin(TAU * BEEP_FREQUENCY * sample_index / SAMPLE_RATE)
		samples.encode_s16(sample_index * 2, int(amplitude * envelope * 9000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = samples
	return stream
#endregion


func _on_timer_timeout() -> void:
	_icon_mesh.visible = false
	label.visible = false
