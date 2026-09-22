extends Node

const SAMPLE_RATE: int = 22050
const BEEP_SECONDS: float = 0.12
const BEEP_FREQUENCY: float = 1200.0
const FEEDBACK_SECONDS: float = 2.0

@onready var label: Label3D = $Result
@onready var beep: AudioStreamPlayer3D = $Beep
var _remaining: float = 0.0


#region Lifecycle
func _ready() -> void:
	var scanner: E_Scanner = get_parent() as E_Scanner
	scanner.scan_feedback.connect(_on_scan_feedback)
	beep.stream = _make_beep()
	label.visible = false


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	label.visible = _remaining > 0.0
#endregion


#region Presentation
func _on_scan_feedback(result: ScanResult) -> void:
	label.text = result.message
	var success: bool = result.outcome != ScanResult.Outcome.REJECTED
	label.modulate = Color.LIGHT_GREEN if success else Color.ORANGE
	_remaining = FEEDBACK_SECONDS
	if result.outcome != ScanResult.Outcome.REJECTED:
		beep.pitch_scale = 1.0 if result.outcome == ScanResult.Outcome.REGISTERED else 0.8
		beep.play()


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
