extends CanvasLayer

@export var player: Entity = null
@onready var prompt: Label = $Overlay/Prompt
@onready var phase_label: Label = $Overlay/DayPhase

const PHASE_NAMES: Array[String] = ["Утро", "День", "Вечер", "Ночь"]


func _process(_delta: float) -> void:
	visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var cycle: C_DayCycle = S_DayPhase.current()
	phase_label.text = (
		"День %d · %s" % [cycle.day_index, PHASE_NAMES[cycle.phase]] if cycle != null else ""
	)
	if not S_Grab.holder_available(player):
		prompt.text = ""
		return
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	prompt.text = interactor.prompt_text if interactor != null else ""
